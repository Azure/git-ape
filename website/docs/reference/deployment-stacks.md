---
title: "Azure Deployment Stacks"
sidebar_label: "Deployment Stacks"
sidebar_position: 4
description: "Why Git-Ape uses Deployment Stacks instead of az deployment sub create"
---

# Azure Deployment Stacks

Git-Ape uses **[Azure Deployment Stacks](https://learn.microsoft.com/azure/azure-resource-manager/bicep/deployment-stacks)** as the deployment primitive. The reason: idempotent destroy across multi-RG and multi-scope deployments. `az group delete` alone leaves orphans; stacks track every resource they create regardless of scope.

## Lifecycle commands

| Pipeline | Command |
|---|---|
| **plan** (validate) | `az stack sub validate --name <id> --action-on-unmanage deleteAll --deny-settings-mode none ...` |
| **plan** (preview) | `az deployment sub what-if --location ... --template-file ...` (works for stacks too) |
| **deploy** | `az stack sub create --name <id> --action-on-unmanage deleteAll --deny-settings-mode none --yes` |
| **destroy** | `az stack sub delete --name <id> --action-on-unmanage deleteAll --yes` |
| **plan** (destroy mode) | `az stack sub show --name <id>` to render the destroy plan |

The stack name **equals the deployment ID** (e.g. `deploy-20260218-143022-myapp`).

### Flag choices

- `--action-on-unmanage deleteAll`: deletes managed resources AND the RGs they're in
- `--deny-settings-mode none`: no deny settings (the PR-and-merge workflow is the change-control mechanism). Switch to `denyDelete` or `denyWriteAndDelete` if your org needs them.

## State captured per deploy

```json
{
  "deployMethod": "stack",
  "stackId": "/subscriptions/.../providers/Microsoft.Resources/deploymentStacks/<id>",
  "resourceGroups": ["rg-..."],
  "managedResources": [
    { "id": "...", "status": "managed", "denyStatus": "none" }
  ]
}
```

Full schema: [`deployment/state`](../deployment/state).

## Soft-delete sweep

After `az stack sub delete` returns, the destroy pipeline iterates pre-recorded soft-deletable resource IDs (Key Vault today; Log Analytics, Cognitive Services, App Configuration, Recovery Services, API Management are pre-captured but not yet purged). Per resource:

| Condition | Action | Recorded |
|---|---|---|
| Already hard-deleted | nothing | — |
| `purgeProtection: false` | `az keyvault purge` | `state.purgedResources[]` |
| `purgeProtection: true` | nothing | `state.retainedSoftDeleted[]` with `scheduledPurgeDate` |
| Purge call failed | log warning | `state.retainedSoftDeleted[]` with `reason: purge-failed` |

JSON arrays built with `jq -n --arg/--argjson` for shell-escape safety.

End state in `state.json`:

```json
{
  "status": "destroyed",                          // or "retained-soft-deleted"
  "destroyedAt": "2026-02-18T23:48:32Z",
  "purgedResources": ["/subscriptions/.../vaults/kv-myapp-dev-..."],
  "retainedSoftDeleted": [
    {
      "resourceId": "/subscriptions/.../vaults/kv-myapp-prod-...",
      "reason": "purge-protected",
      "scheduledPurgeDate": "2026-05-19T12:33:06+00:00"
    }
  ]
}
```

Re-run is idempotent — purged stays purged, retained stays retained.

## Destroy plan PR comment

When a PR sets `metadata.json.status = destroy-requested`, plan calls `scripts/render-destroy-plan.sh` to produce a stack-aware deletion preview:

```
Stack: deploy-20260218-143022-myapp
Action on unmanage: deleteAll
Total managed resources: 7

Resource changes: 7 to delete

Scope: /subscriptions/.../resourceGroups/rg-myapp-dev-eus (eastus)
  - Microsoft.KeyVault/vaults/kv-myapp-dev-abc123
      tags: CreatedDate=2026-02-18, Environment=dev, ...
  - Microsoft.Network/virtualNetworks/vnet-myapp-dev-eus
  ...
```

Plus a soft-delete callout when applicable:

> 🛡️ Key Vault `kv-myapp-dev-abc123` has **purge protection enabled** → soft-delete retained 7–90 days

## Path B: legacy fallback

For pre-Stacks deployments (no `deployMethod` field), destroy falls back to:

1. Read `state.resourceGroup`
2. `az group delete --yes` (no soft-delete sweep — no `managedResources` to iterate)
3. Update state to `destroyed`

Path B will be removed once all live deployments are stack-based.
