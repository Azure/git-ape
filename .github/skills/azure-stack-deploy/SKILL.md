---
name: azure-stack-deploy
description: "Run an Azure Deployment Stack create (subscription scope) for a prepared Git-Ape deployment artifact and write state.json (schemaVersion 1.0). Use locally so the result matches the CI deploy workflow."
argument-hint: "Deployment ID (folder under .azure/deployments/) — optional --location override"
user-invocable: true
---

# Azure Stack Deploy

Deploy a Git-Ape deployment artifact as a subscription-scoped **Azure Deployment Stack** (`az stack sub create --action-on-unmanage deleteAll`). The stack is the lifecycle owner of every resource the template creates — across resource groups and subscription scope — which makes destroy idempotent in a single call (see [`azure-stack-destroy`](../azure-stack-destroy/SKILL.md)).

This skill produces the **same `state.json`** schema (`schemaVersion: "1.0"`) as the CI workflow at `.github/workflows/git-ape-deploy.yml`, so local deployments and pipeline deployments are interchangeable.

## When to Use

- Local deployment from VS Code or terminal (the `git-ape` agent invokes this in Stage 3)
- Re-deploying an existing deployment ID after template edits — stacks are stateful, so this is an in-place update
- Any time you would otherwise run `az deployment sub create` against a Git-Ape `template.json`

## Do NOT use for

- **Tearing down / destroying** an existing deployment — use [`azure-stack-destroy`](../azure-stack-destroy/SKILL.md) instead
- **What-if preview / preflight validation** without deploying — use [`azure-deployment-preflight`](../azure-deployment-preflight/SKILL.md) instead
- **Off-topic** (non-Azure, non-deployment) requests
- Generating or editing ARM templates — use `azure-prepare` or another IaC authoring skill

## Prerequisites

| Tool | Why |
|------|-----|
| `az` (Azure CLI ≥ 2.59) | `az stack sub` requires CLI ≥ 2.50; 2.59 has the latest stack flags |
| `jq` | State capture and JSON extraction |
| `bash` ≥ 4 OR PowerShell 7+ | Either runner works |
| Active `az login` | Skill exits early if no subscription is selected |
| Existing `template.json` (and optional `parameters.json`) under `.azure/deployments/<id>/` | Source artifacts |

## Procedure

### 1. Locate deployment artifacts

```bash
DEPLOYMENT_ID="deploy-20260506-001"
DEPLOYMENT_PATH=".azure/deployments/$DEPLOYMENT_ID"

[[ -f "$DEPLOYMENT_PATH/template.json" ]] || { echo "template.json missing"; exit 1; }
```

If `parameters.json` is present, `location`, `project` (or `projectName`), and `environment` are read from it. Defaults: `eastus` / `unknown` / `dev`.

### 2. Run the script

```bash
.github/skills/azure-stack-deploy/scripts/deploy-stack.sh \
  --deployment-id "$DEPLOYMENT_ID"
```

PowerShell equivalent:

```powershell
.github/skills/azure-stack-deploy/scripts/deploy-stack.ps1 `
  -DeploymentId "$DEPLOYMENT_ID"
```

The script:

1. Resolves `location`, `project`, `environment` from `parameters.json` (or defaults)
2. Validates Azure CLI session (`az account show`)
3. Calls `az stack sub create` with the canonical Git-Ape flag set:
   - `--action-on-unmanage deleteAll`
   - `--deny-settings-mode none`
   - `--description "Git-Ape deployment <id>"`
   - `--tags managedBy=git-ape deploymentId=<id>`
   - `--yes --verbose`
4. **On stack failure**, falls back to `az deployment sub create` and prints `⚠️ FALLBACK: no multi-RG idempotency, no soft-delete tracking` so the trade-off is unambiguous
5. **On any deployment failure**, dumps the per-operation failure list (`az deployment operation sub list`) inline so the root cause is visible without clicking into the Portal
6. **On success**, queries `az stack sub show --query "resources[].id"` for the live managed-resource list, classifies each resource (type, scope, soft-deletable, purge-protected), and writes the extended `state.json`
7. Updates `metadata.json` with `status: "succeeded"`, `deployMethod`, and `resourceGroups[]`

### 3. Inspect output

```text
✅ Deployment succeeded in 142s (method: stack)
State written to: .azure/deployments/deploy-20260506-001/state.json
Stack ID: /subscriptions/<sub>/providers/Microsoft.Resources/deploymentStacks/deploy-20260506-001

To destroy this deployment:
  /azure-stack-destroy deploy-20260506-001
```

## What to tell the user after running

After the script returns, your reply MUST mention:

1. The primitive used: `az stack sub create --action-on-unmanage deleteAll` (or fallback `az deployment sub create`)
2. The stack ID (from `state.json.stackId`) — this is the single handle for destroy
3. That `state.json` (schemaVersion 1.0) was written under the deployment folder
4. The next-step destroy command: `/azure-stack-destroy <deploymentId>`

## Arguments

| Flag (bash) | Param (pwsh) | Required | Description |
|-------------|--------------|----------|-------------|
| `--deployment-id <id>` | `-DeploymentId <id>` | yes | Folder name under `.azure/deployments/` |
| `--location <region>` | `-Location <region>` | no | Override the location from `parameters.json` |
| `--no-fallback` | `-NoFallback` | no | Fail loudly if the stack call fails instead of falling back to `az deployment sub create` |

## state.json schema (v1.0)

```json
{
  "schemaVersion": "1.0",
  "deploymentId": "deploy-20260506-001",
  "timestamp": "2026-05-06T12:00:00Z",
  "status": "succeeded",
  "duration": "142s",
  "subscription": "<sub-id>",
  "location": "eastus",
  "project": "myapp",
  "environment": "dev",
  "resourceGroup": "rg-myapp-dev-eastus",
  "deployMethod": "stack",
  "stackId": "/subscriptions/<sub>/providers/Microsoft.Resources/deploymentStacks/deploy-20260506-001",
  "managedResources": [
    {
      "id": "/subscriptions/<sub>/resourceGroups/rg-myapp-dev-eastus/providers/Microsoft.KeyVault/vaults/kv-myapp-dev-eus",
      "type": "Microsoft.KeyVault/vaults",
      "scope": "resourceGroup",
      "softDeletable": true,
      "purgeProtected": true
    }
  ],
  "resourceGroups": ["rg-myapp-dev-eastus"],
  "subscriptions": ["<sub-id>"],
  "externalReferences": []
}
```

See [website/docs/deployment/state.md](../../../website/docs/deployment/state.md) for the full schema reference.

## Soft-deletable resource types tracked

`Microsoft.KeyVault/vaults`, `Microsoft.CognitiveServices/accounts`, `Microsoft.AppConfiguration/configurationStores`, `Microsoft.ApiManagement/service`, `Microsoft.MachineLearningServices/workspaces`, `Microsoft.RecoveryServices/vaults`.

The destroy skill ([`azure-stack-destroy`](../azure-stack-destroy/SKILL.md)) consumes the `softDeletable` and `purgeProtected` fields to drive its purge sweep.

## Failure modes

| Symptom | Likely cause | Recovery |
|---------|--------------|----------|
| `Not logged in to Azure` | `az login` missing | Run `az login` then retry |
| `template.json missing` | Wrong deployment ID | Check `.azure/deployments/` contents |
| Stack create fails immediately | Region/policy blocks Deployment Stacks | Re-run without `--no-fallback`, accept the legacy path, or pick a supported region |
| Stack succeeds but `state.json` missing managed resources | `az stack sub show` race condition | Re-run — the script is idempotent (stacks de-duplicate on `--name`) |

## Related

- [`azure-stack-destroy`](../azure-stack-destroy/SKILL.md) — the matching destroy skill (single source of truth: `stackId`)
- [`azure-deployment-preflight`](../azure-deployment-preflight/SKILL.md) — what-if and permission checks BEFORE deploy
- [`azure-security-analyzer`](../azure-security-analyzer/SKILL.md) — security gate (BLOCKING) before deploy confirmation
