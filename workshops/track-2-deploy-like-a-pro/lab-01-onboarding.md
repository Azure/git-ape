# Lab 1: Onboarding

> 10 minutes | Azure required (Owner or User Access Administrator role)

Set up OIDC federated identity, RBAC, and GitHub environments for CI/CD.

> **What this teaches you:** how Git-Ape creates a zero-secrets Azure trust relationship — an Entra app registration + service principal + federated credentials wired to your repo, with RBAC scoped exactly to what deployments need. See [identity-model.md](../shared/identity-model.md) for the full picture.

## Step 0: Pre-flight (do not skip)

This step ensures your environment is fully configured **before** you invoke the onboarding agent. Each item below tells you what to check, what it should look like, and exactly how to fix it.

### 0.1 Install required CLI tools

```bash
# macOS
brew install azure-cli gh jq git

# Ubuntu / WSL
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
(type -p wget >/dev/null || sudo apt install wget -y) && \
  sudo mkdir -p -m 755 /etc/apt/keyrings && \
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null && \
  sudo apt update && sudo apt install gh jq git -y

# Windows (PowerShell)
winget install Microsoft.AzureCLI GitHub.cli stedolan.jq Git.Git
```

### 0.2 Authenticate both CLIs

```bash
# Azure — opens browser for interactive login
az login

# Verify you're logged in and note your subscription name
az account show --query "{name:name, id:id, state:state}" -o table
```

```bash
# GitHub — opens browser for OAuth flow
gh auth login

# Verify
gh auth status
```

### 0.3 Select the correct Azure subscription

```bash
# List all subscriptions
az account list --query "[].{Name:name, Id:id, State:state}" -o table

# Switch if needed (replace with your subscription name or ID)
az account set --subscription "<your-subscription-name>"

# Confirm the state is "Enabled" — a Disabled sub silently fails RBAC writes
az account show --query state -o tsv
# Expected output: Enabled
```

### 0.4 Verify you have sufficient Azure permissions

You need **Owner** or **User Access Administrator** role to create app registrations and assign RBAC roles during onboarding.

```bash
# Check your role assignments
MY_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment list --assignee "$MY_ID" --all \
  --query "[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator'].{Role:roleDefinitionName, Scope:scope}" \
  -o table
```

**Expected:** At least one row showing `Owner` or `User Access Administrator` on your subscription scope.

> **Don't have Owner?** You can still follow this lab in **review-only mode** — the onboarding agent shows every command it would run without executing them. Ask your subscription admin for temporary elevated access if you want to run it live.

### 0.5 Verify your tenant allows app registration creation

Some organisations restrict who can create app registrations. You'll only discover this during Step 2 if it's blocked.

```bash
# Quick check — if this returns a result, you can create apps
az ad app list --filter "displayName eq 'test-preflight-check'" --query "length(@)" -o tsv
# Any output (even "0") means you have permission. An "Authorization_RequestDenied" error means you don't.
```

> **If blocked:** Ask your Azure AD tenant admin to either grant you the `Application Developer` role, or pre-create the app registration for you.

### 0.6 Verify your repo's default branch is `main`

```bash
git symbolic-ref --short HEAD
# Expected: main
```

If your default branch is `master`, rename it:

```bash
git branch -m master main
git push -u origin main
# Then update the default branch in GitHub: Settings → General → Default branch
```

### 0.7 Run the automated pre-flight script

All of the above checks (and more) are packaged in a single script:

```bash
bash workshops/shared/check-track-2-prereqs.sh
```

This will show PASS/FAIL/WARN for every check with exact fix commands. **All items must be PASS or WARN before proceeding to Step 1.**

### Pre-flight summary

| # | Check | Pass criteria |
|---|---|---|
| 0.1 | CLI tools installed | `az`, `gh`, `jq`, `git` all on PATH |
| 0.2 | Both CLIs authenticated | `az account show` and `gh auth status` succeed |
| 0.3 | Subscription enabled | `az account show --query state` returns `Enabled` |
| 0.4 | Owner or UAA role | Role assignment list shows Owner or User Access Administrator |
| 0.5 | App registration allowed | No `Authorization_RequestDenied` error |
| 0.6 | Default branch is `main` | `git symbolic-ref --short HEAD` returns `main` |
| 0.7 | Pre-flight script passes | All checks PASS or WARN |

## Step 1: Verify Azure Access

```bash
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
```

If wrong subscription: `az account set --subscription "<name>"`.

## Step 2: Run the Onboarding Skill

In Copilot Chat, type:

```text
@git-ape-onboarding onboard this repository
```

The onboarding agent walks you through:

1. **Repository URL** — auto-detected from your current repo
2. **App Registration name** — creates an Azure AD identity (e.g., `sp-git-ape-workshop`)
3. **Environment mode** — choose "Single environment" for this workshop
4. **Azure subscription** — defaults to your current subscription
5. **RBAC role** — choose "Contributor" (minimum for deployments)

Watch as the agent:

- Creates an Entra ID App Registration
- Configures OIDC federated credentials (main branch + pull requests + environment)
- Assigns RBAC roles on your subscription
- Creates GitHub environments (`azure-deploy`, `azure-destroy`)
- Sets GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)
- **Scaffolds the Git-Ape workflow files** (`git-ape-plan.yml`,
  `-deploy.yml`, `-destroy.yml`, `-verify.yml`, `-drift.{md,lock.yml}`)
  and `.github/copilot-instructions.md` into your working copy
  (skip-with-notice on collision; files left unstaged)

## Step 3: Verify the Setup

Run the verification workflow:

```text
/prereq-check
```

Or trigger the verification workflow from the terminal:

```bash
gh workflow run git-ape-verify.yml
```

## What Just Happened

| Component | Purpose |
|-----------|---------|
| **App Registration** | Azure AD identity that GitHub Actions uses to authenticate |
| **OIDC federated credential** | Trust relationship: GitHub can exchange tokens with Azure without secrets |
| **RBAC role assignment** | The app registration has Contributor access to your subscription |
| **GitHub environments** | `azure-deploy` and `azure-destroy` with protection rules |
| **GitHub secrets** | Client ID, Tenant ID, Subscription ID (identifiers, not passwords) |
| **Workflow files** | `git-ape-plan/deploy/destroy/verify` plus `drift.{md,lock.yml}` scaffolded into `.github/workflows/` (unstaged) |
| **Deployment standards** | `.github/copilot-instructions.md` scaffolded so every Git-Ape agent shares the same guardrails |

> **Key insight:** No passwords or connection strings were created. OIDC uses short-lived tokens exchanged at runtime. This is the "zero secrets" approach.

### Review-Only Path

If you don't have Owner role, you can review the onboarding process without executing it. The agent shows you every command it would run. In Track 3, you'll see these credentials used in CI/CD workflows.

**Next:** [Lab 2 — Web App + SQL](lab-02-web-app-sql.md)

## Step 4: Diagnose OIDC subject mismatches

The most common post-onboarding failure is AADSTS700213 No matching federated identity record on the first GitHub Actions run. Cause: org uses customized OIDC subject template.

Check:

    gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'

If false, onboarding auto-uses ID-based subjects; verify with:

    APP_ID=$(az ad app list --display-name "sp-<your-project>" --query "[0].id" -o tsv)
    az ad app federated-credential list --id "$APP_ID" -o table

See identity-model.md for the full OIDC trust flow.

## Step 5: Reconcile scaffolded files

The scaffold step is non-destructive. If your repo already has .github/workflows/git-ape-*.yml, onboarding skips them and leaves new files unstaged. Check git status .github/ and reconcile.

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Authorization_RequestDenied at app create | Tenant blocks user app registration | Ask tenant admin |
| RoleAssignmentNotFound on first deploy | RBAC propagation 60-90s | Wait 90s and retry |
| AADSTS700213 on first workflow | OIDC subject mismatch | See Step 4 |
| Subscription state Disabled | Billing issue | Switch sub |

## Anti-patterns

- Do not assign Owner on the sub when Contributor + User Access Administrator suffices.
- Do not commit the AZURE_CLIENT_ID to public places (it is only an identifier but aids recon).
- Do not skip Step 4 verification -- AADSTS700213 in CI is much harder to diagnose later.

## Going further

- Skill source of truth: .github/skills/git-ape-onboarding/SKILL.md
- Agent contract: .github/agents/git-ape-onboarding.agent.md
- Full identity model: ../shared/identity-model.md
