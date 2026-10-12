# Prerequisites

> Comprehensive setup checklist for every workshop track. Verify each item **before** the workshop starts — most workshop failures are caught here.

## Quick start

Run the Copilot prereq check first:

```text
/prereq-check
```

For deeper per-track Azure/GitHub validation:

```bash
bash workshops/shared/check-track-1-prereqs.sh   # or -2 / -3 / -4
```

If either fails, the relevant section below explains the exact fix.

## Track requirements at a glance

| | T1 (Zero to Deploy) | T2 (Deploy Like a Pro) | T3 (Platform Engineering) | T4 (Executive Briefing) |
|---|:---:|:---:|:---:|:---:|
| Dev environment | ✓ | ✓ | ✓ | ✓ |
| GitHub Copilot subscription | ✓ | ✓ | ✓ | ✓ |
| Azure CLI 2.50+ / GitHub CLI 2.0+ / jq 1.6+ | — | ✓ | ✓ | demo only |
| Azure subscription (Contributor+) | — | ✓ | ✓ | demo only |
| **Owner** or **User Access Administrator** on target subscription | — | ✓ (Lab 1) | — | — |
| GitHub repo admin on workshop repo | — | ✓ (Lab 1) | ✓ | — |
| GitHub Actions: "Allow GH Actions to create and approve pull requests" enabled | — | ✓ (Lab 1) | ✓ | — |
| GitHub environments `azure-deploy` and `azure-destroy` (set up by Lab 1) | — | ✓ | ✓ | — |

## 1. Development environment

Pick one. Container-based options (A and B) pre-install all required CLI tools.

| Option | What you need | Best for |
|---|---|---|
| **A: GitHub Codespaces** | GitHub account + web browser | Fastest start, zero local installs |
| **B: VS Code + Dev Containers** | Docker Desktop + VS Code | Pre-configured local environment |
| **C: VS Code local** | VS Code + manual tool install | Full local control, no Docker |

Detailed setup: [environment-setup.md](environment-setup.md).

## 2. GitHub Copilot access

Git-Ape runs inside GitHub Copilot Chat. You need one of GitHub Copilot Individual, Business, or Enterprise. Verify at github.com/settings/copilot. The Git-Ape extension must be visible in the Copilot Chat extensions panel.

## 3. Required CLI tools (Tracks 2 and 3)

Container-based dev environments (Codespaces, Dev Container) pre-install these.

| Tool | Min | Verify | Purpose |
|---|---|---|---|
| `az` Azure CLI | 2.50 | `az version` | Azure resource mgmt, RBAC, deployments |
| `gh` GitHub CLI | 2.0 | `gh --version` | Repo / secrets / environments / PRs |
| `jq` | 1.6 | `jq --version` | JSON parsing |
| `git` | any | `git --version` | Version control |

## 4. Azure subscription (Tracks 2-3, T4 demo)

You need a real Azure subscription (sandbox or dev recommended, never production).

### Minimum RBAC

| Lab | Required role | Why |
|---|---|---|
| T2 Lab 1 (Onboarding) | **Owner** OR **User Access Administrator** | Creates the Entra app registration + federated credentials + RBAC role assignments |
| T2 Labs 2-5 | **Contributor** | Deploys resources |
| T3 Labs 1-6 | **Contributor** + **User Access Administrator** | CI/CD pipeline assigns RBAC roles inside ARM templates |

Verify your role:

```bash
az role assignment list --assignee $(az ad signed-in-user show --query id -o tsv) --output table
```

### Subscription must be active

```bash
az account show --query "{name:name, state:state}" -o table
```

If `state` is anything other than `Enabled` (e.g., `Disabled`, `Warned`, `PastDue`), RBAC writes and deploys silently fail. Switch subscription or contact your billing admin.

### Resource providers must be registered

Subscriptions don't auto-enable every Azure service. Pre-register the providers each track uses:

```bash
# Track 1/2 (Function Apps + App Service + Storage + App Insights)
az provider register --namespace Microsoft.Web --wait
az provider register --namespace Microsoft.Storage --wait
az provider register --namespace Microsoft.Insights --wait

# Track 2 (SQL + Key Vault)
az provider register --namespace Microsoft.Sql --wait
az provider register --namespace Microsoft.KeyVault --wait

# Track 3 (Container Apps)
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
```

If you skip this, the first deploy fails with `MissingSubscriptionRegistration` — annoying but recoverable mid-lab.

### Region quota

The lab defaults (`eastus`, `westus2`, `southeastasia`) usually have headroom in workshop sandboxes. If your sandbox is constrained, check:

```bash
az vm list-usage --location eastus -o table
```

If a SKU is at 100%, pick a different region in the lab's parameter file.

## 5. Identity model — what onboarding actually creates

Track 2 Lab 1 creates an **Entra ID app registration plus its service principal**. This is the identity GitHub Actions uses to deploy. It is NOT a "service principal with secret" (no password is ever stored).

The three Entra identity types you may encounter:

| Type | What it is | Used by Git-Ape? |
|---|---|---|
| **Entra App Registration** | Identity object + permissions, lives in the directory | Yes — created by onboarding |
| **Service Principal** | The app registration's instance in your tenant | Yes — created alongside the app registration |
| **Managed Identity** | Identity automatically assigned to an Azure resource (e.g., a Function App) | Yes — every workload Git-Ape deploys gets a managed identity for runtime access |

See [identity-model.md](identity-model.md) for the full picture (OIDC trust diagram, federated credentials, why "zero secrets").

### Tenant policy gotcha

Some Entra tenants disable "Users can register applications" — in which case Lab 1 fails at `az ad app create` with `Authorization_RequestDenied`. Ask your tenant admin to:

1. Enable user app registration, **or**
2. Pre-create the app registration and grant you Owner on it.

## 6. GitHub repo settings (Tracks 2-3)

The workshop repo must satisfy these settings BEFORE Track 2 Lab 1:

| Setting | Required value | Where |
|---|---|---|
| Default branch | `main` | Repo Settings → Branches |
| Actions: allow GH Actions to create and approve pull requests | **Enabled** | Repo Settings → Actions → General → Workflow permissions |
| Actions: workflow permissions | Read-only repository contents permission (default) — workflows that need more declare it via `permissions:` blocks | same place |
| Environments `azure-deploy` and `azure-destroy` | Created by Lab 1 (don't pre-create) | Repo Settings → Environments |
| Branch protection on `main` | Recommended: require PR review before merge | Repo Settings → Branches → Add rule |

The "Allow GH Actions to create and approve pull requests" setting is **OFF by default** in org-owned repos. Without it, workflows that open PRs (e.g., `git-ape-deck-build.yml`) fail with `GitHub Actions is not permitted to create or approve pull requests`.

## 7. GitHub org-level settings

These are usually fine but worth checking with your org admin:

- **OIDC subject template** — some orgs (e.g., the Azure org) customize the OIDC subject format. Onboarding auto-detects via:

  ```bash
  gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
  ```

  If `false`, onboarding uses the numeric-ID-based subject format instead of `repo:org/repo`. If it gets this wrong, deploys fail at runtime with `AADSTS700213: No matching federated identity record`.
- **Copilot Coding Agent enabled** (T3 Lab 2 only) — Settings → Code & automation → Copilot coding agent.
- **GitHub Actions enabled** for the repo at org level.

## 8. Verification

Run the per-track check script for the track you're about to attend:

```bash
bash workshops/shared/check-track-2-prereqs.sh
```

It exits 0 with a `✓ ready` message, or non-zero with the exact `az`/`gh` fix for each failing check.

If you don't have an Azure subscription, every lab includes a **review-only path** that walks through the same artifacts without actually deploying.
