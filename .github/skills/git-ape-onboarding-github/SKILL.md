---
name: git-ape-onboarding-github
description: GitHub Actions-specific onboarding playbook for Git-Ape. Activates the four GitHub workflows (plan, deploy, destroy, verify), triggers the verify workflow, and enumerates GitHub-specific gotchas (org OIDC subject template, environment secrets). Called by the `git-ape-onboarding` orchestrator skill after the shared OIDC + RBAC setup is complete. Do not invoke directly — let the orchestrator dispatch to this skill.
---

# Git-Ape GitHub Actions Onboarding (sub-skill)

This sub-skill contains the GitHub Actions-only steps of the Git-Ape onboarding playbook. It is intended to be **dispatched from `git-ape-onboarding`** after the shared steps (1–10) have already completed:

- App registration created
- Federated credentials added (per-branch + per-environment subjects)
- RBAC assigned
- GitHub environments created (`azure-deploy`, `azure-destroy`)
- Required GitHub secrets seeded (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

Inputs expected from the orchestrator:

| Variable | Example | Source |
|---|---|---|
| `GITHUB_REPO` | `contoso/myapp-infra` | Step 1 (resolve metadata) |
| `GITHUB_ORG` | `contoso` | Step 1 |

## Step A — Activate workflows

Rename `.exampleyml` files to `.yml` in `.github/workflows/`. The four workflows are committed to the repo as `.exampleyml` so that they don't trigger before onboarding completes.

**Files to activate:**
- `git-ape-plan.exampleyml` → `git-ape-plan.yml` (validates template and shows what-if)
- `git-ape-deploy.exampleyml` → `git-ape-deploy.yml` (executes deployments)
- `git-ape-destroy.exampleyml` → `git-ape-destroy.yml` (tears down resources)
- `git-ape-verify.exampleyml` → `git-ape-verify.yml` (post-deploy verification)

**Rename commands (Unix/macOS/Linux):**
```bash
cd .github/workflows
for f in *.exampleyml; do
  target="${f%.exampleyml}.yml"
  mv "$f" "$target"
  echo "Renamed: $f -> $target"
done
```

**Rename commands (Windows PowerShell):**
```powershell
cd .github\workflows
Get-ChildItem *.exampleyml | ForEach-Object {
  $newName = $_.Name -replace '\.exampleyml$', '.yml'
  Rename-Item -Path $_.FullName -NewName $newName
  Write-Host "Renamed: $($_.Name) -> $newName"
}
```

**Verification (all platforms):**
```bash
ls .github/workflows/git-ape-*.yml
```

Should output:
```
git-ape-deploy.yml
git-ape-destroy.yml
git-ape-plan.yml
git-ape-verify.yml
```

## Step B — Run setup verification

Trigger the verify workflow once after activation, poll for completion, and gate "onboarding complete" on its result.

```bash
gh workflow run git-ape-verify.yml --repo "$GITHUB_REPO" --ref main

# Poll for the most recent run (allow ~10s for it to register)
sleep 10
RUN_ID=$(gh run list --workflow=git-ape-verify.yml --repo "$GITHUB_REPO" --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch "$RUN_ID" --repo "$GITHUB_REPO" --exit-status

VERIFY_STATUS=$(gh run view "$RUN_ID" --repo "$GITHUB_REPO" --json conclusion -q '.conclusion')
VERIFY_URL=$(gh run view "$RUN_ID" --repo "$GITHUB_REPO" --json url -q '.url')
```

**Exit conditions:**
- `success` → onboarding is complete; tell the user they can open their first deployment PR
- `failure` → STOP. Print the failed steps from the run log and ask the user to inspect (commonly: missing RBAC role on subscription, federated credential subject mismatch — see Gotcha A below)
- `timed_out` → STOP. Likely no runner available — check Actions runner availability

Do NOT mark onboarding as complete unless `VERIFY_STATUS == success`.

## Output for the orchestrator

Return to the orchestrator a status summary that the orchestrator merges into its Step 11 / Step 12 output:

```
GitHub Actions:
  - git-ape-plan.yml         activated
  - git-ape-deploy.yml       activated
  - git-ape-destroy.yml      activated
  - git-ape-verify.yml       activated
  Verify workflow run:       ✅ <VERIFY_STATUS> ($VERIFY_URL)
```

## Provider-specific gotchas (GitHub)

### A. GitHub Org Custom OIDC Subject Template (e.g. Azure org)

Some GitHub organizations (notably the `Azure` org) override the default OIDC subject claim template to use **numeric ID-based** subjects instead of name-based ones.

The orchestrator's Step 1 should auto-detect this via:
```bash
gh api "orgs/$GITHUB_ORG/actions/oidc/customization/sub" --jq '.use_default'
```

- Returns `true` → standard format: `repo:contoso/myapp-infra:pull_request`
- Returns `false` → ID format: `repository_owner_id:6844498:repository_id:1184905165:pull_request`

If OIDC login fails with `AADSTS700213: No matching federated identity record`, the federated credential subjects don't match what GitHub is presenting. Fix by re-running onboarding (the orchestrator will auto-detect and use the correct format), or manually updating existing credentials:

```bash
# Get repo/owner IDs
gh api "repos/$GITHUB_REPO" --jq '{repo_id: .id, owner_id: .owner.id}'

# Update each federated credential with correct subject
az ad app federated-credential update \
  --id <APP_OBJECT_ID> \
  --federated-credential-id <CRED_ID> \
  --parameters '{"subject":"repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>:pull_request"}'
```

### B. Federated credential subjects must match exactly

Each subject the workflow presents at runtime needs a matching federated credential on the App Registration. The orchestrator's Step 4 creates credentials for these subjects:

- `repo:<org>/<repo>:ref:refs/heads/main`
- `repo:<org>/<repo>:pull_request`
- `repo:<org>/<repo>:environment:azure-deploy`
- `repo:<org>/<repo>:environment:azure-deploy-staging` (multi-env mode only)
- `repo:<org>/<repo>:environment:azure-deploy-prod` (multi-env mode only)
- `repo:<org>/<repo>:environment:azure-destroy`

If you add a new environment to the workflows after onboarding, you MUST also add a corresponding federated credential — the OIDC token exchange will fail otherwise.

### C. `permissions:` block required for OIDC

Workflows that use `azure/login@v2` with OIDC must declare `permissions: id-token: write` at either the workflow or job scope. Without it, GitHub does not issue an OIDC token, and login fails with a misleading "no credentials" error.

The Git-Ape workflows already declare this; if you copy a workflow as a starting point for a new one, preserve the `permissions:` block.

### D. Environment secrets vs repo secrets

Git-Ape stores `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` at the **environment** level (per `azure-deploy*`/`azure-destroy`), not the repo level. This lets multi-environment mode use different App Registrations / subscriptions per environment.

If `${{ secrets.AZURE_CLIENT_ID }}` resolves to an empty string at runtime:
- The workflow step's `environment:` field is missing or wrong, OR
- The secret is set at repo scope only (use `gh secret set --env <env>` not `gh secret set` alone)

### E. PR comment posting needs `pull-requests: write`

The plan workflow posts the consolidated plan as a PR comment. This requires `permissions: pull-requests: write` in the workflow (or a fine-grained PAT, which Git-Ape avoids). Without it the workflow succeeds but the comment post silently 403s.

### F. Coding Agent flow restrictions

When Git-Ape runs as the GitHub Copilot Coding Agent on a branch:
- The agent cannot interactively prompt — it generates artifacts and opens a PR
- Deployment is gated by the `azure-deploy` environment approval, NOT by a chat command
- The `/deploy` early-deploy comment trigger (workflow_dispatch via issue_comment) requires `permissions: contents: write, pull-requests: write` AND the comment author must be a repo collaborator with write access

### G. No org-level secrets for OIDC identifiers

Even though `AZURE_CLIENT_ID` is non-secret, prefer environment-scoped storage to keep multi-environment mode working consistently. Org-level secrets work but make per-environment App Registration rotation harder to reason about.
