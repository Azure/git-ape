---
title: "GitHub Actions Workflows"
sidebar_label: "GitHub Actions Workflows"
sidebar_position: 7
description: "GitHub Actions anatomy — triggers, matrix, /deploy comment, OIDC permissions"
---

# GitHub Actions Workflows

Per-workflow anatomy for `.github/workflows/git-ape-*.yml`. For Azure DevOps see [`azure-devops-pipelines`](./azure-devops-pipelines). For the high-level overview see [`pipeline-architecture`](./pipeline-architecture).

## Layout

```
.github/workflows/
├── git-ape-plan.yml        ~470 lines  PR: validate, what-if, IaC scans, post PR comment
├── git-ape-deploy.yml      ~250 lines  Merge OR /deploy comment: az stack sub create
├── git-ape-destroy.yml     ~310 lines  Merge (when destroy-requested): stack delete + sweep
└── git-ape-verify.yml      ~280 lines  Manual: OIDC + RBAC check
```

GitHub Actions has no `templates/` mechanism. Shared bash logic lives in `.azure-pipelines/scripts/` and is referenced by both providers — checkout pulls the same repo. Three scripts: `render-pr-comment.sh`, `render-summary.sh`, `render-destroy-plan.sh`.

## Plan workflow

### Trigger

```yaml
on:
  pull_request:
    paths:
      - '.azure/deployments/**/template.json'
      - '.azure/deployments/**/parameters.json'
      - '.azure/deployments/**/metadata.json'
```

GitHub honours `on:` triggers verbatim — no Branch Policy required.

### Job layout

```yaml
jobs:
  detect:
    outputs:
      matrix: ${{ steps.find.outputs.matrix }}
      has_deployments: ${{ steps.find.outputs.has_deployments }}

  plan:
    needs: detect
    if: needs.detect.outputs.has_deployments == 'true'
    strategy:
      matrix: ${{ fromJson(needs.detect.outputs.matrix) }}
      max-parallel: 5
      fail-fast: false

  post_pr_comment:
    needs: [detect, plan]
    if: |
      always() &&
      needs.detect.outputs.has_deployments == 'true' &&
      contains(fromJson('["success", "failure"]'), needs.plan.result)
```

### Per-deployment matrix slot

1. `actions/checkout@v4` with `fetch-depth: 0`
2. `azure/login@v2` (OIDC)
3. Read deployment parameters → set env vars
4. Enforce required tags (deploy action only)
5. `az stack sub validate` (deploy action only)
6. `az deployment sub what-if` (deploy action only, **independent** of validate)
7. `actions/setup-python@v5` with `cache: 'pip'`
8. `pip install --user checkov`
9. Install `PSRule.Rules.Azure` + clone `arm-ttk` (pwsh comes pre-installed on `ubuntu-latest`)
10. Run IaC scans **in parallel** via bash `& wait`
11. `scripts/render-destroy-plan.sh` (destroy action only)
12. Capture deployment artifacts
13. Render PR comment body + summary JSON
14. `actions/upload-artifact@v4`

**Step 13 must run before step 14** — same constraint as `PublishPipelineArtifact@1` in ADO.

### Aggregator

```yaml
post_pr_comment:
  needs: [detect, plan]
  steps:
    - uses: actions/download-artifact@v4
      with:
        path: artifacts/        # no name = downloads everything
    - uses: actions/github-script@v7
      with:
        github-token: ${{ secrets.GITHUB_TOKEN }}
        script: |
          const marker = '<!-- git-ape-plan -->';
          const body = require('fs').readFileSync('./body.md', 'utf8');
          const { data: comments } = await github.rest.issues.listComments({...});
          const existing = comments.find(c => c.body.includes(marker));
          if (existing) {
            await github.rest.issues.updateComment({comment_id: existing.id, body});
          } else {
            await github.rest.issues.createComment({body});
          }
```

## Deploy workflow

### Triggers

```yaml
on:
  push:
    branches: [main]
    paths: ['.azure/deployments/**/template.json', '...']
  issue_comment:
    types: [created]
```

`/deploy` comment trigger:

```yaml
deploy:
  if: |
    (github.event_name == 'push' && github.ref == 'refs/heads/main') ||
    (github.event_name == 'issue_comment' &&
     github.event.issue.pull_request &&
     contains(github.event.comment.body, '/deploy') &&
     contains(fromJson('["MEMBER", "OWNER", "COLLABORATOR"]'),
              github.event.comment.author_association))
  environment: azure-deploy
  permissions:
    id-token: write          # OIDC
    contents: write          # state.json commit
    pull-requests: write     # post deploy result to PR
```

### Parallel `az stack sub create`

Same bash `& wait` pattern as ADO. See [`azure-devops-pipelines#parallel-az-stack-sub-create`](./azure-devops-pipelines#parallel-az-stack-sub-create) for the full bash.

### State commit-back

Uses workflow's `GITHUB_TOKEN` (with `permissions.contents: write`) — no separate ACL grant needed:

```bash
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit -m "git-ape: update deployment state [skip ci]"
git push origin HEAD:main
```

`[skip ci]` prevents trigger loops. Branch protection rules don't affect `GITHUB_TOKEN` pushes when `permissions:` is set correctly.

## Destroy workflow

### Triggers

```yaml
on:
  push:
    branches: [main]
    paths: ['.azure/deployments/**/metadata.json']
  workflow_dispatch:
    inputs:
      deployment_id: { required: true }
      confirmation:  { required: true, type: choice, options: [destroy] }
```

`azure-destroy` environment should have stricter required reviewers than `azure-deploy` — destroy is irreversible.

Same parallel destroy + soft-delete sweep pattern as ADO. See [`azure-devops-pipelines#destroy-pipeline`](./azure-devops-pipelines#destroy-pipeline).

## Verify workflow

```yaml
on:
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
```

Same checks as ADO verify pipeline, but tooling check is much simpler: `ubuntu-latest` always has jq, git, curl, python3, pip, pwsh pre-installed. Just confirms `az stack` is available.

## Why `actions/setup-python@v5` works here

GitHub-hosted runners maintain a populated tool cache. `setup-python@v5` looks up the cache, sets PATH, and (with `cache: 'pip'`) restores cached pip packages. Materially simpler than ADO's pattern (which has to install via apt because `UsePythonVersion@0`'s tool cache is empty on self-hosted).

## Cross-platform notes

Workflows pin to `runs-on: ubuntu-latest` because:
- All bash scripts assume bash 4+ semantics (`<<<` herestring, `${VAR:-default}`)
- Azure CLI is well-tested on Ubuntu

If you need macOS/Windows: bash scripts work under WSL/Git Bash, but YAML steps need `shell: bash` on Windows.

## Trigger summary

| Trigger | plan | deploy | destroy | verify |
|---|---|---|---|---|
| `pull_request` | ✅ | — | — | — |
| `push` to main | — | ✅ | ✅ (status guard) | — |
| `issue_comment` `/deploy` | — | ✅ (collaborator only) | — | — |
| `workflow_dispatch` | — | — | ✅ (manual fallback) | ✅ |

## Robustness baseline

Same as ADO: `set -euo pipefail`, `${VAR:-default}`, curl retries, `timeout-minutes`, `fetch-depth: 0` for git history, `continue-on-error: true` on best-effort steps. See [`troubleshooting`](./troubleshooting) for the failure modes that motivated each.
