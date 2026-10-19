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

The workflow reads `state.json` for the stack name and calls `/azure-stack-destroy` under the hood (the same primitive used for local CLI/VS Code teardown):

1. Reads `state.json` for the deployment stack name (`stackId`).
2. Runs `az stack sub show` to inventory every resource the stack manages — across resource groups and subscription scope (role assignments, policy assignments).
3. Runs `az stack sub delete --action-on-unmanage deleteAll --bypass-stack-out-of-sync-error true` — one call deletes everything the stack owns, no orphans.
4. Purges soft-deletable resources that linger after stack deletion (Key Vault, Cognitive Services) unless flagged `purgeProtected: true`.
5. Updates `state.json` and `metadata.json` to `destroyed` and commits the updated state to the repo.

If the stack is already gone, the workflow records `already-destroyed` and exits `0` — safe to re-run.

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

If you have other workshop resources still deployed from earlier labs, use `/azure-stack-destroy` for each deployment ID rather than a raw `az group delete`:

```text
@git-ape /azure-stack-destroy deploy-XXXXXXXX-XXXXXX
```

> **Why not `az group delete`?** A Git-Ape deployment stack often spans multiple resource groups plus subscription-scope resources (role/policy assignments) — a single `az group delete` only cleans one RG. `/azure-stack-destroy` also purges soft-deletable resources (Key Vault, Cognitive Services) that otherwise linger for 7-90 days and block re-deploying with the same name. Reserve `az group delete` for resource groups you created by hand outside Git-Ape.

### What's Next?

- **Explore more skills:** Search the core + community skill registry with `/git-ape-skills search <capability>` (e.g. `/git-ape-skills search cost`), or browse the [full skill catalog](https://github.com/Azure/git-ape). Community entries are reviewed through Azure/git-ape PRs but installed only with your explicit approval, pinned to a commit — see `.github/skills/git-ape-skills/SKILL.md`.
- **Architecture review:** Ask `@azure-principal-architect` to review any deployment
- **Contribute:** Open a PR to improve workshop content or add new scenarios

## Step 6: The destroy contract

`git-ape-destroy.yml` triggers when `metadata.json` status flips to `destroy-requested` and the PR merges, OR via manual `workflow_dispatch` with `confirm=destroy`. Both require PR review.
