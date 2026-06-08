# Lab 5: IaC Export

> 10 minutes | Azure required (needs existing resources)

Export existing Azure resources to ARM templates and bring them under Git-Ape management.

## What You Learn

- How to reverse-engineer live Azure resources into IaC
- How the IaC Exporter generates ARM templates from deployed state
- How to import legacy infrastructure into Git-Ape management

## Step 1: Identify Resources to Export

You need an existing resource group with deployed resources. Use one from a previous lab:

**Bash / macOS / Linux:**

```bash
az group list --query "[?starts_with(name, 'rg-')].{Name:name, Location:location}" -o table
```

**PowerShell / Windows:**

```powershell
az group list --query "[?starts_with(name, 'rg-')].{Name:name, Location:location}" -o table
```

Pick a resource group to export.

## Step 2: Run the IaC Exporter

In Copilot Chat:

```text
@azure-iac-exporter export rg-inventoryapp-dev-eastus
```

Replace the resource group name with your actual group.

## Step 3: Review the Exported Template

The exporter generates:
- ARM template with all resource definitions
- Parameter file with current configuration values
- Resource relationship mapping

Compare the exported template with the original:
- Resource types and API versions
- Properties and configurations
- Dependencies between resources

## Step 4: Import into Git-Ape Management

The exported files can be saved to `.azure/deployments/` to bring them under Git-Ape's state management:

```text
@git-ape import the exported template as a managed deployment
```

This creates:
- `metadata.json` with status `imported`
- `state.json` with current resource IDs
- `requirements.json` reverse-engineered from the template

## Step 5: Run Drift Detection on Imported Resources

Now that the resources are under Git-Ape management, you can detect drift:

```text
/azure-drift-detector
```

Any manual changes since export will show as drift.

## What You Learned

| Concept | What It Means |
|---------|--------------|
| **IaC Export** | Reverse-engineer live resources into ARM templates |
| **Import to management** | Bring existing resources under Git-Ape state tracking |
| **Drift baseline** | After import, drift detection works against the exported state |
| **Legacy migration** | Gradually bring portal-created resources under IaC management |

**Next:** [Lab 6 — Destroy Lifecycle](lab-06-destroy-lifecycle.md)

## Step 6: Use cases

IaC Exporter helps when:
- You inherited an undocumented Azure RG and need an ARM template.
- You need to bring existing resources under Git-Ape management.
- You want a starting point for a similar deployment elsewhere.

## Step 7: What gets exported (and what doesn't)

- Exported: ARM resource definitions, dependencies, network config, RBAC scoped to the RG.
- NOT exported: secrets (Key Vault values), runtime data (blobs, DB contents), platform-managed identities.

After export, review the template -- it represents what's there, not what you'd write fresh. Often you'll want to tighten (add managed identities, remove deprecated settings) before adopting.

## Step 8: Adoption workflow

1. Export -> template + state in .azure/deployments/<id>/.
2. Review for what to keep vs improve.
3. Run security analyzer; expect findings (existing resources rarely meet Git-Ape's bar).
4. Decide: adopt as-is, fix in template before re-deploy, or migrate via parallel deployment.

## Going further

- Agent: .github/agents/azure-iac-exporter.agent.md
