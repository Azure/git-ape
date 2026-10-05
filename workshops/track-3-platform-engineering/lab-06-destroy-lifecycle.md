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

The workflow:

1. Reads `state.json` to find the deployment stack name (`deploymentId`) and `stackId`
2. Calls `az stack sub show` to inventory the stack's managed resources across every resource group and subscription scope
3. Calls `az stack sub delete --action-on-unmanage deleteAll` — a single idempotent call that removes every resource the stack manages (resource groups, role assignments, policy assignments), with no RG-by-RG sweep needed
4. Updates `state.json` and `metadata.json` to `destroyed` (or `already-destroyed` if the stack was already gone)
5. Commits the updated state to the repo

> The stack is the single unit of lifecycle. One delete call cleans up everything the stack manages, no orphans, and it's safe to re-run (see Step 8).

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

If you have other workshop deployments still standing, use the **`/azure-stack-destroy`** skill rather than `az group delete` directly — it's the only path that also purges soft-deleted Key Vaults/Cognitive Services and covers resources at subscription scope (role/policy assignments) that a plain resource-group delete would miss:

```text
/azure-stack-destroy <deployment-id>
```

Or from the command line:

```bash
.github/skills/azure-stack-destroy/scripts/destroy-stack.sh --deployment-id "<deployment-id>" --yes
```

> Only fall back to `az group delete --name <rg> --yes --no-wait` for resource groups you created by hand outside Git-Ape (no matching `state.json`) — never for a Git-Ape-managed deployment, since it skips the soft-delete purge and any subscription-scope cleanup.

### What's Next?

- **Explore more skills:** Browse the [full skill catalog](https://github.com/Azure/git-ape)
- **Architecture review:** Ask `@azure-principal-architect` to review any deployment
- **Contribute:** Open a PR to improve workshop content or add new scenarios

## Step 6: The destroy contract

`git-ape-destroy.yml` triggers when `metadata.json` status flips to `destroy-requested` and the PR merges, OR via manual `workflow_dispatch` with `confirm=destroy`. Both require PR review.

## Step 7: Same primitive, local or CI

The exact same `az stack sub delete --action-on-unmanage deleteAll --bypass-stack-out-of-sync-error true` call backs both this CI workflow and the local **`/azure-stack-destroy`** skill used above — so a local teardown and a PR-merge teardown always produce the same result.

## Step 8: Idempotency

If the stack is already gone, the workflow (and the skill) records `already-destroyed` and exits 0. Safe to re-run.
