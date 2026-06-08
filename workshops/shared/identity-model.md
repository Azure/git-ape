# Identity Model

> One-page explainer for how Git-Ape authenticates with Azure. Read this before Track 2 Lab 1.

## The three identities you will meet

Attendees often conflate Entra App Registration, Service Principal, and Managed Identity. They are three distinct things and Git-Ape uses all three at different layers.

| Type | What it is | Lives where | Used by Git-Ape for |
|---|---|---|---|
| **Entra App Registration** | An identity object plus permissions defined at the directory level | Microsoft Entra ID (tenant) | The identity GitHub Actions uses to deploy |
| **Service Principal** | The tenant-specific instance of an app registration; the thing RBAC roles get assigned to | Microsoft Entra ID (tenant) | What `az role assignment create --assignee <SP_OBJECT_ID>` targets |
| **Managed Identity** | An identity that an Azure resource automatically owns | The Azure resource itself | Runtime access from the deployed workload, e.g., a Function App reading a Key Vault secret |

**Mental model**: the app registration is the "user" definition; the service principal is "that user signed into your tenant"; the managed identity is what your deployed apps use to talk to other Azure services at runtime.

## What Track 2 Lab 1 actually creates

```
   Track 2 Lab 1 (onboarding)
            |
            v
   +------------------------------+
   |   Entra ID (your tenant)     |
   |                              |
   |   App Registration           |
   |     "sp-<project>-<env>"     |
   |           |                  |
   |           v                  |
   |   Service Principal          |
   |     (instance in tenant)     |
   |           |                  |
   |           | Federated        |
   |           | Credentials      |
   |           v                  |
   |   +----------------------+   |
   |   | fc-main-branch       |   |
   |   | fc-pull-request      |   |
   |   | fc-azure-deploy      |   |
   |   | fc-azure-destroy     |   |
   |   +----------------------+   |
   +------------------------------+
            +
   +------------------------------+
   |   Azure subscription         |
   |   RBAC roles -> the SP       |
   |   (Contributor / UAA)        |
   +------------------------------+
            +
   +------------------------------+
   |   GitHub repo                |
   |   secrets:                   |
   |   - AZURE_CLIENT_ID          |
   |   - AZURE_TENANT_ID          |
   |   - AZURE_SUBSCRIPTION_ID    |
   |   environments:              |
   |   - azure-deploy             |
   |   - azure-destroy            |
   +------------------------------+
```

## OIDC: how GitHub Actions authenticates without secrets

When `git-ape-deploy.yml` runs, the `azure/login@v2` action makes a token-exchange call:

```
   1. GitHub Actions runner gets a short-lived OIDC token from GitHub
      Subject claim: "repo:<org>/<repo>:ref:refs/heads/main"  (or environment-based)

   2. Runner POSTs the OIDC token to Entra's STS along with AZURE_CLIENT_ID

   3. Entra checks the federated credential on the app registration:
      - Does any federated credential subject match the OIDC subject claim?
      - YES -> issue an Azure access token bound to the service principal
      - NO  -> AADSTS700213 No matching federated identity record

   4. Runner uses the Azure access token to make az calls.
      No password ever leaves Entra. The OIDC token lives ~5 minutes.
```

**Why this matters**: zero static secrets in GitHub. Nothing to rotate, nothing to leak from a stolen repo dump. The trust is in (a) the federated credential subject, (b) GitHub's OIDC issuer, (c) the explicit RBAC roles granted to the service principal.

## Federated credential subject formats

Default GitHub orgs use **name-based** OIDC subjects:

```
repo:<org>/<repo>:ref:refs/heads/main
repo:<org>/<repo>:pull_request
repo:<org>/<repo>:environment:azure-deploy
repo:<org>/<repo>:environment:azure-destroy
```

Some orgs (notably the **Azure** org) customise their OIDC template to use **numeric IDs** instead:

```
repository_id:<numeric>:ref:refs/heads/main
...
```

Onboarding auto-detects which format your org uses:

```bash
gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
```

- Returns `true`  -> use the name-based subject format.
- Returns `false` -> use the ID-based subject format. Onboarding looks up the numeric IDs via `gh api repos/<org>/<repo>`.

If the federated credential subject doesn't match the OIDC token's claim, every workflow run fails at the Azure login step with **AADSTS700213: No matching federated identity record**.

## What about the deployed workload's identity?

The app registration only authenticates GitHub Actions to Azure. The workloads it deploys (Function Apps, Web Apps, Container Apps) use their **own** managed identities for runtime access:

- A Function App's managed identity reads from Key Vault.
- A Container App's managed identity authenticates to SQL.
- These are configured in the ARM template the Template Generator produces.

That is why you will not see `connectionStrings` or `AzureWebJobsStorage` (key-based) in Git-Ape templates — every resource-to-resource connection is identity-based.

## Verification commands

After Lab 1, you can confirm everything wired up:

```bash
az ad app list --display-name "sp-<project>-<env>" --query "[].{name:displayName,id:appId,objectId:id}" -o table
az ad app federated-credential list --id <APP_OBJECT_ID> -o table
az role assignment list --assignee-object-id <SP_OBJECT_ID> --all -o table
gh secret list
gh api repos/{owner}/{repo}/environments --jq '.environments[].name'
```

## Further reading

- [Microsoft Learn: workload identity federation for GitHub Actions](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation-create-trust-github)
- [GitHub Docs: customizing the OIDC subject claim](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#customizing-the-token-claims)
- [troubleshooting.md](troubleshooting.md) — workshop pre-flight failure modes including AADSTS700213