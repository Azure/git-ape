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

The workflow also supports manual `workflow_dispatch` with `confirm=destroy` as an emergency fallback.

The workflow:

1. Reads the stack name (`deploymentId`) and `stackId` from `state.json`
2. Runs `az stack sub show` to inventory the stack's managed resources
3. Runs `az stack sub delete --action-on-unmanage deleteAll` — removes every managed resource across all resource groups and subscription scope in one call
4. Updates `state.json` and `metadata.json` to `destroyed`
5. Commits the updated state to the repo

If the stack is already gone, the workflow records `already-destroyed` and exits successfully, so re-runs are safe.

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

## Step 6: Destroy Locally with the `azure-stack-destroy` Skill

The CI workflow is the default path, but the same teardown is available locally. The `azure-stack-destroy` skill mirrors `git-ape-destroy.yml`, so local and CI destroys are interchangeable. It pairs with `azure-stack-deploy`, which creates the stack and writes `state.json` (schemaVersion 1.0).

In Copilot Chat, ask:

```text
@git-ape destroy deployment deploy-XXXXXXXX-XXXXXX
```

The skill:

1. Refuses to run without `state.json` under `.azure/deployments/<id>/`
2. Deletes the stack with `az stack sub delete --action-on-unmanage deleteAll --bypass-stack-out-of-sync-error true`
3. Purges soft-deleted Key Vault, Cognitive Services and similar resources, unless flagged `purgeProtected: true` in `state.json`
4. Updates `state.json` and `metadata.json` to a terminal status

Prefer it over raw `az group delete`: a stack can own several resource groups plus subscription-scope resources, and soft-deleted resources keep holding their names after a group delete.

> **No Azure?** Read `.github/skills/azure-stack-destroy/SKILL.md` and trace which of the steps above apply to a sample `state.json`.

## Workshop Complete

> **Track 3 complete.** You built a CI/CD pipeline, used headless mode, promoted across environments, assessed policy compliance, exported existing resources, and completed a full lifecycle teardown. Total time: ~90 minutes.

### Clean Up Remaining Resources

If you have other workshop resources still deployed:

**Bash / macOS / Linux:**

```bash
# List all workshop resource groups
az group list --query "[?starts_with(name, 'rg-')].name" -o tsv

# Delete each one
az group delete --name <resource-group-name> --yes --no-wait
```

**PowerShell / Windows:**

```powershell
# List all workshop resource groups
az group list --query "[?starts_with(name, 'rg-')].name" -o tsv

# Delete each one
az group delete --name <resource-group-name> --yes --no-wait
```

### What's Next?

- **Explore more skills:** Browse the [full skill catalog](https://github.com/Azure/git-ape)
- **Architecture review:** Ask `@azure-principal-architect` to review any deployment
- **Contribute:** Open a PR to improve workshop content or add new scenarios
