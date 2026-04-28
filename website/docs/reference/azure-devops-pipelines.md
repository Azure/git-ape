---
title: "Azure DevOps Pipelines"
sidebar_label: "Azure DevOps Pipelines"
sidebar_position: 6
description: "ADO pipeline anatomy — templates, scripts, matrix, parallelism, cross-host bootstrap"
---

# Azure DevOps Pipelines

Per-pipeline anatomy for `.azure-pipelines/git-ape-*.yml`. For GitHub Actions see [`github-actions-workflows`](./github-actions-workflows). For the high-level overview see [`pipeline-architecture`](./pipeline-architecture).

## Layout

```
.azure-pipelines/
├── git-ape-plan.yml            ~580 lines  PR: validate, what-if, IaC scans, post PR comment
├── git-ape-deploy.yml          ~270 lines  Merge: az stack sub create, integration tests
├── git-ape-destroy.yml         ~330 lines  Merge (when destroy-requested): stack delete + sweep
├── git-ape-verify.yml          ~325 lines  Manual: OIDC + RBAC + tooling check
├── templates/
│   ├── bootstrap-prereqs.yml      Cross-host install: jq always, python+pwsh on demand
│   └── commit-and-push-state.yml  git push state.json/metadata.json with [skip ci]
└── scripts/                       (shared with GitHub Actions)
    ├── render-pr-comment.sh       Per-deployment Markdown body
    ├── render-summary.sh          Per-deployment summary JSON for the aggregator's table
    └── render-destroy-plan.sh     Stack-aware destroy plan
```

## Plan pipeline

Three jobs in one stage:

```yaml
stages:
  - stage: Plan
    jobs:
      - job: detect_deployments       # ~10s
      - job: plan                     # matrix, maxParallel: 5
        dependsOn: detect_deployments
        strategy:
          matrix: $[ dependencies.detect_deployments.outputs['find.DEPLOYMENT_IDS'] ]
          maxParallel: 5
      - job: post_pr_comment          # runs after matrix
        dependsOn: [detect_deployments, plan]
        condition: |
          and(
            eq(dependencies.detect_deployments.outputs['find.HAS_DEPLOYMENTS'], 'true'),
            in(dependencies.plan.result, 'Succeeded', 'SucceededWithIssues', 'Failed')
          )
```

Per-deployment matrix slot, in order:

1. `templates/bootstrap-prereqs.yml` (jq + python + pwsh)
2. Read deployment parameters → set `LOCATION`, `DEPLOY_DIR`
3. Enforce required tags (deploy action only)
4. `az stack sub validate` (deploy action only)
5. `az deployment sub what-if` (deploy action only, **independent** of validate result)
6. Run IaC scans **in parallel** via bash `& wait` (Checkov + ARM-TTK + PSRule)
7. `scripts/render-destroy-plan.sh` (destroy action only)
8. Capture deployment artifacts (architecture, cost, security)
9. Render PR comment body + summary JSON via `scripts/render-pr-comment.sh` + `render-summary.sh`
10. `PublishPipelineArtifact@1`

**Step 9 must run before step 10** — `PublishPipelineArtifact@1` snapshots its target dir at task time.

### IaC scanner parallelism

```bash
run_checkov & CHECKOV_PID=$!
run_armttk  & ARMTTK_PID=$!
run_psrule  & PSRULE_PID=$!
wait $CHECKOV_PID $ARMTTK_PID $PSRULE_PID || true
```

Per-scanner status files (`.status.checkov`, etc.) avoid concurrent-write races on the canonical `status.tsv`. After `wait`, status files are concatenated. The format is `scanner<TAB>status<TAB>reason`; the renderer surfaces skipped/failed scanners in the PR comment.

### Aggregator job

```yaml
- job: post_pr_comment
  steps:
    - checkout: none
    - template: templates/bootstrap-prereqs.yml
    - download: current      # downloads ALL artifacts (no name = everything)
    - bash: |                # build summary table + collapsibles, post one PR thread
```

Body composition:
1. Marker `<!-- git-ape-plan -->` (no per-id suffix → one comment per PR)
2. `## Git-Ape Plan` heading
3. **Summary table** (always visible, one row per `summary-*.json`)
4. Per-deployment detail (inline if N=1, `<details>` if N>1)

POST/PATCH to threads API: lookup by marker → if found, PATCH; else POST.

## Deploy pipeline

```yaml
- stage: Detect
- stage: Deploy                       # gated by 'azure-deploy' environment
    jobs:
      - deployment: deploy
        environment: azure-deploy
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - template: templates/bootstrap-prereqs.yml
                - download: current
                  artifact: detect
                - task: AzureCLI@2    # parallel az stack sub create per deployment
                - task: AzureCLI@2    # parallel integration tests
                - template: templates/commit-and-push-state.yml
```

**No separate Validate stage** — plan already validated; `az stack sub create` validates server-side.

### Parallel `az stack sub create`

```bash
deploy_one() {
  local DEPLOYMENT_ID="$1"
  local LOG="$LOG_DIR/$DEPLOYMENT_ID.log"
  { ... az stack sub create ... } > "$LOG" 2>&1
}

PIDS=()
while read -r DEPLOYMENT_ID; do
  deploy_one "$DEPLOYMENT_ID" &
  PIDS+=($!)
done < <(echo "$DEPLOYMENT_IDS" | jq -r '.[]')

for PID in "${PIDS[@]}"; do
  wait "$PID" || FAILED=$((FAILED + 1))
done

# Stream per-deployment logs IN ORDER for readability
for LOG in "$LOG_DIR"/*.log; do
  echo "═══ $(basename "$LOG" .log) ═══"
  cat "$LOG"
done
```

A 2-stack deploy takes ~max(stack), not sum (~91s for 2 vs ~85s for 1).

## Destroy pipeline

Same Detect → Destroy(stage) split, gated by `azure-destroy`. Inside the destroy step:

```bash
# Path A: stack
if [[ "$DEPLOY_METHOD" == "stack" ]]; then
  az stack sub delete --name "$DEPLOYMENT_ID" --action-on-unmanage deleteAll --yes
  for RES_ID in $(echo "$SOFT_DELETABLE" | jq -r '.[]'); do
    if [[ "$RES_ID" == */Microsoft.KeyVault/vaults/* ]]; then
      # purge or retain
    fi
  done
# Path B: legacy
else
  az group delete --name "$RG" --yes
fi
```

JSON arrays for `purgedResources[]` / `retainedSoftDeleted[]` use `jq -n --arg/--argjson` (safe against shell-escape pitfalls).

## Verify pipeline

```bash
TOOLS=(
  "az|required|already present on Microsoft-hosted images & in our agent container"
  "jq|required|apt-get install -y jq"
  "git|required|apt-get install -y git"
  "curl|required|apt-get install -y curl"
  "python3|required|apt-get install -y python3 python3-pip"
  "checkov|recommended|python3 -m pip install checkov"
  "pwsh|recommended|needed for ARM-TTK and PSRule"
)
```

Onboarding skill gates "complete" on `MISSING_REQUIRED == 0`.

## Shared templates

### `bootstrap-prereqs.yml`

Cross-host install. Parameters: `withPython` (bool, default false), `withPwsh` (bool, default false). Plan calls with both true; deploy/destroy/verify use defaults (jq only).

`install_pkg` helper tries package managers in order: apt-get → brew → dnf/yum → choco. For pwsh on Linux: downloads `packages-microsoft-prod.deb`, dpkg-installs, then `apt-get install powershell`.

All best-effort with `continueOnError: true`.

### `commit-and-push-state.yml`

```bash
git add .azure/deployments/*/state.json .azure/deployments/*/metadata.json
git diff --cached --quiet && exit 0
git commit -m "${{ parameters.commitMessage }}"   # includes [skip ci]
git -c http.extraHeader="Authorization: Bearer $SYSTEM_ACCESSTOKEN" \
  push "$REMOTE_URL" "HEAD:refs/heads/main"
```

`[skip ci]` prevents trigger loops. The push needs build identity ACL `allow=16516` (GenericContribute + PolicyExempt + PullRequestContribute) — see [troubleshooting → TF402455](./troubleshooting#tf402455-pushes-to-this-branch-are-not-permitted-you-must-use-a-pull-request-to-update-this-branch).

## Shared scripts

| Script | Args | Output |
|---|---|---|
| `render-pr-comment.sh` | `<deployment_id> <action> <staging_dir>` | Markdown body to stdout |
| `render-summary.sh` | `<deployment_id> <action> <staging_dir>` | Summary JSON to stdout |
| `render-destroy-plan.sh` | `<deployment_id> <action> <staging_dir>` | Stack-aware destroy plan to stdout |

All read optional files from `<staging_dir>` (validation status, destroy status, what-if output, scan results, architecture, cost, security analysis). Missing files just skip their section.

## File-based status passing

ADO's `$(stepName.OutputVar)` macro expands to literal text at queue time. If the producing step is skipped, the macro stays as-is in the bash script and runs as command substitution → `command not found`, exit 127.

**Fix**: write status to file (always, not just on success), read with default in consumer:

```yaml
# Producer
- task: AzureCLI@2
  name: validate
  inputs:
    inlineScript: |
      echo "passed" > "$STAGING/validation-$(deployment_id).txt"

# Consumer
- bash: |
    VALIDATION_STATUS="skipped"
    [[ -f "$STAGING/validation-$DEPLOYMENT_ID.txt" ]] && \
      VALIDATION_STATUS=$(cat "$STAGING/validation-$DEPLOYMENT_ID.txt")
```

## Triggers (ADO-specific)

| Pipeline | Trigger |
|---|---|
| plan | **Branch Policy → Build Validation** (YAML `pr:` is silently ignored on Azure Repos) |
| deploy | `trigger: branches: [main], paths: [...]` |
| destroy | `trigger: branches: [main], paths: [.azure/deployments/**/metadata.json]` (script verifies status) |
| verify | manual only |

## Robustness baseline

Applied across all pipelines:
- `set -euo pipefail` at the top of every bash step
- `${VAR:-default}` for every potentially-unset env var
- `curl --retry 3 --retry-delay 2 --max-time 30` on PR-comment HTTP calls
- `timeoutInMinutes:` set explicitly per job (10 detect, 15 verify, 30 plan, 120 deploy/destroy)
- `fetchDepth: 0` for jobs that need git history
- `continueOnError: true` on best-effort steps

See [`troubleshooting`](./troubleshooting) for the bug-hunt history that motivated each.
