# Lab 6: Destroy Lifecycle

> 5 minutes | Azure required

Tear down resources using the PR-based destroy workflow. Complete the full deployment lifecycle.

## What You Learn

- How to request resource destruction through a PR
- How `git-ape-destroy.yml` automates teardown
- How the audit trail is preserved after destruction

## Step 1: Request Destruction via PR

The destroy workflow is triggered by setting `metadata.json` status to `destroy-requested`.

Create a branch:

```bash
git checkout -b destroy/workshop-cleanup
```

Update the metadata file for one of your deployments:

**Bash / macOS / Linux:**

```bash
# Find your deployment directory
ls .azure/deployments/

# Update the status (replace with your actual deployment ID)
DEPLOY_DIR=".azure/deployments/deploy-XXXXXXXX-XXXXXX"

# Use jq to update the status
jq '.status = "destroy-requested"' "$DEPLOY_DIR/metadata.json" > tmp.json \
  && mv tmp.json "$DEPLOY_DIR/metadata.json"
```

**PowerShell / Windows:**

```powershell
# Find your deployment directory
Get-ChildItem .azure/deployments/

# Update the status (replace with your actual deployment ID)
$DeployDir = ".azure/deployments/deploy-XXXXXXXX-XXXXXX"

# Read, update, and write the metadata
$meta = Get-Content "$DeployDir/metadata.json" | ConvertFrom-Json
$meta.status = "destroy-requested"
$meta | ConvertTo-Json -Depth 10 | Set-Content "$DeployDir/metadata.json"
```

Commit and push:

```bash
git add .azure/deployments/
git commit -m "chore: request destruction of workshop resources"
git push origin destroy/workshop-cleanup
```

## Step 2: Open a Destroy PR

```bash
gh pr create --title "Destroy: Workshop resources cleanup" \
  --body "Requests teardown of workshop deployment resources. Status set to destroy-requested." \
  --base main
```

## Step 3: Review and Merge

The `git-ape-plan.yml` workflow detects the `destroy-requested` status change and includes a teardown warning in the PR comment.

After review, merge the PR:

```bash
gh pr review --approve
gh pr merge --squash
```

## Step 4: Watch the Destroy Workflow

The `git-ape-destroy.yml` workflow triggers on merge:

```bash
gh run list --workflow=git-ape-destroy.yml --limit 1
gh run watch
```

The workflow reads `state.json` for the **Azure Deployment Stack** name (`stackId`), then:

1. Runs `az stack sub show` to inventory every resource the stack manages — across resource groups *and* subscription scope (role assignments, policy assignments)
2. Runs `az stack sub delete --action-on-unmanage deleteAll --bypass-stack-out-of-sync-error true` — one call removes everything the stack owns, no orphans
3. Purges soft-deleted resources that aren't purge-protected (Key Vault, Cognitive Services, etc.) so names free up immediately
4. Updates `state.json` and `metadata.json` to `destroyed`
5. Commits the updated state to the repo

**Idempotent by design:** if the stack is already gone, the workflow records `already-destroyed` and exits 0 — safe to re-run.

> Doing this from the local CLI or VS Code instead of a PR? Use the **`azure-stack-destroy`** skill — it runs the exact same `az stack sub delete` primitive and writes the same `state.json`, so local and CI teardown are interchangeable. It **refuses to run without an existing `state.json`** — don't hand-write one.

## Step 5: Verify Destruction

**Bash / macOS / Linux:**

```bash
git pull
cat .azure/deployments/deploy-*/metadata.json | jq '.status'
```

**PowerShell / Windows:**

```powershell
git pull
Get-ChildItem .azure/deployments/deploy-*/metadata.json | ForEach-Object {
  (Get-Content $_ | ConvertFrom-Json).status
}
```

Should show `"destroyed"`.

The deployment directory still exists with the full audit trail — template, security analysis, cost estimate, and deployment logs. Only the Azure resources are gone.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **PR-based teardown** | Destruction requires a PR, review, and approval — same as creation |
| **Human gate** | No automated deletion without explicit merge approval |
| **State update** | `state.json` and `metadata.json` updated to `destroyed` |
| **Audit preservation** | All deployment artifacts preserved even after resources are deleted |
| **Full lifecycle** | planning → deployed → destroy-requested → destroyed |

## Workshop Complete

> **Track 3 complete.** You built a CI/CD pipeline, used headless mode, promoted across environments, assessed policy compliance, exported existing resources, and completed a full lifecycle teardown. Total time: ~90 minutes.

### Clean Up Remaining Resources

If you have other workshop deployments still standing, use the same stack-based teardown for each `deploymentId` under `.azure/deployments/` — do **not** fall back to `az group delete`: a stack can span multiple resource groups plus subscription-scope resources, and `az group delete` misses both those and the soft-delete purge.

**Bash / macOS / Linux:**

```bash
# List your workshop deployment IDs
ls .azure/deployments/

# Destroy each one (requires state.json in that folder)
.github/skills/azure-stack-destroy/scripts/destroy-stack.sh --deployment-id <deployment-id> --yes
```

**PowerShell / Windows:**

```powershell
# List your workshop deployment IDs
Get-ChildItem .azure/deployments/

# Destroy each one (requires state.json in that folder)
.github/skills/azure-stack-destroy/scripts/destroy-stack.ps1 -DeploymentId <deployment-id> -Yes
```

### What's Next?

- **Explore more skills:** Browse the [full skill catalog](https://github.com/Azure/git-ape)
- **Architecture review:** Ask `@azure-principal-architect` to review any deployment
- **Contribute:** Open a PR to improve workshop content or add new scenarios

## Notes

- `git-ape-destroy.yml` triggers when `metadata.json` status flips to `destroy-requested` and the PR merges, OR via manual `workflow_dispatch` with `confirm=destroy`. Both paths require PR review.
- If the stack is already gone, the workflow (and the `azure-stack-destroy` skill) record `already-destroyed` and exit 0 — safe to re-run.
