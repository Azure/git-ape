---
name: git-ape-onboarding
description: "Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets."
metadata:
  argument-hint: "GitHub repo URL, subscription target(s), and onboarding mode (single or multi-environment)"
  user-invocable: true
---

# Git-Ape Onboarding

Use this skill to bootstrap a repository for Git-Ape deployments by executing the onboarding workflow directly from Copilot Chat.

This skill is the source of truth for onboarding behavior. Do not depend on a standalone repository script for setup logic.

## When to Use

- First-time setup of a repository for Git-Ape
- New subscription onboarding (single environment)
- Multi-environment onboarding (dev/staging/prod across different subscriptions)
- New user handoff where OIDC, RBAC, and GitHub environments must be created

## What It Configures

This skill configures:

1. Entra ID App Registration and service principal (or reuses existing)
2. OIDC federated credentials for GitHub Actions
3. RBAC role assignment(s) on subscription scope
4. GitHub environments (`azure-deploy*`, `azure-destroy`)
5. Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`) and the `AZURE_SUBSCRIPTION_ID` variable, plus the optional `GIT_APE_RUNNER_LABEL` variable that selects private runners
6. Scaffolded GitHub Actions workflow files (`git-ape-plan.yml`, `-deploy.yml`, `-destroy.yml`, `-verify.yml`, `-drift.{md,lock.yml}`) and deployment standards (`.github/copilot-instructions.md`) into the user's working copy
7. The GitHub Actions **runner type** the workflows run on — public GitHub-hosted (default) or private self-hosted runners in your Azure subscription (ACI / ACA / AKS, optionally VNet-injected). On-demand IaC for private runners ships at `./templates/runners/`.

## Prerequisites

Before onboarding, run the **prereq-check** skill to verify all required tools are installed and auth sessions are active:

```text
/prereq-check
```

The prereq-check skill validates: `az` (≥ 2.50), `gh` (≥ 2.0), `jq` (≥ 1.6), `git`, and active Azure/GitHub auth sessions. If anything is missing, it shows platform-specific install commands.

Do NOT proceed with onboarding until prereq-check reports **✅ READY**.

Additionally, the Azure identity used must have **Owner** or **User Access Administrator** on the target subscription(s), and the GitHub identity must have **admin** access to the target repository.

## Invariants

These rules are non-negotiable. The agent MUST NOT improvise around them.

- **Default branch is always `main`.** Never use `master`, never auto-detect a non-`main` default, and never substitute any other name. All federated credential subjects, environment branch policies, and example commands use `refs/heads/main` / the literal string `main`. If a user's repository uses something other than `main`, prompt for it once and use the user-supplied value explicitly — never silently default to `master`.
- **Federated credential names use the `fc-main-branch` form,** not `fc-master-branch`. See Step 5 for the canonical subject strings.
- **Workflows ship `main`-targeted triggers.** The scaffold step copies workflow files that reference `branches: [main]`; do not rewrite them to `master`.

## Execution Modes

### Interactive (recommended for first-time use)

Invoke the skill from chat and let the agent gather missing parameters:

```text
/git-ape-onboarding
```

### Parameterized single environment

```text
/git-ape-onboarding onboard https://github.com/org/repo on subscription 00000000-0000-0000-0000-000000000000 with Contributor
```

### Parameterized multi-environment

```text
/git-ape-onboarding onboard https://github.com/org/repo with dev on 11111111-1111-1111-1111-111111111111 as Contributor, staging on 22222222-2222-2222-2222-222222222222 as Contributor, prod on 33333333-3333-3333-3333-333333333333 as Contributor+UserAccessAdministrator
```

## Command Playbook

When the agent executes this skill, it should run the equivalent Azure and GitHub CLI commands directly in this order:

1. Validate prerequisites and current auth context.
2. Resolve repo metadata:
```bash
gh repo view <org>/<repo>
gh api repos/<org>/<repo> --jq '{repo_id: .id, owner_id: .owner.id}'
gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
```
3. Create or reuse the Entra app registration and service principal:
```bash
CLIENT_ID=$(az ad app create --display-name "$SP_NAME" --query appId -o tsv)
az ad sp create --id "$CLIENT_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
```
4. Build the OIDC subject prefix:
```bash
# default format
OIDC_PREFIX="repo:<org>/<repo>"

# if org customization returns false
OIDC_PREFIX="repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>"
```
5. Create federated credentials with these canonical subjects (always `refs/heads/main` — never `master`):
   - `fc-main-branch`     subject `"$OIDC_PREFIX:ref:refs/heads/main"`     description `"Main branch deployments"`
   - `fc-pull-request`    subject `"$OIDC_PREFIX:pull_request"`            description `"Pull request plan/validate"`
   - `fc-azure-deploy`    subject `"$OIDC_PREFIX:environment:azure-deploy"` (one per environment in multi-env mode)
   - `fc-azure-destroy`   subject `"$OIDC_PREFIX:environment:azure-destroy"`
6. Assign RBAC on each target subscription.
7. Set GitHub repo or environment secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`) and the `AZURE_SUBSCRIPTION_ID` variable. (The `GIT_APE_RUNNER_LABEL` variable is set later in Step 11 only if private runners are chosen.)
8. Create GitHub environments and branch policies when permissions allow.
9. Scaffold workflow files and deployment standards into the user's working copy (see below).
10. Capture compliance and Azure Policy preferences (see below).
11. Select the GitHub Actions runner type and, if private runners are chosen, provision them and set `GIT_APE_RUNNER_LABEL` (see below).
12. Verify federated credentials, role assignments, and secrets.

### Step 9: Scaffold workflow files and deployment standards

The GitHub Actions workflows that power Git-Ape (`git-ape-plan.yml`,
`-deploy.yml`, `-destroy.yml`, `-verify.yml`, `-drift.md`, `-drift.lock.yml`)
and the deployment standards file (`.github/copilot-instructions.md`) ship
as templates inside this skill at `./templates/`.

After identity, secrets, and environments are configured, run the scaffold
helper to copy these templates into the user's working copy. Two parity
implementations ship — pick the one that matches the user's shell:

```bash
# macOS / Linux / WSL
./scripts/scaffold-repo.sh
```

```powershell
# Windows (PowerShell 7+)
pwsh .github/skills/git-ape-onboarding/scripts/scaffold-repo.ps1
```

Both scripts produce byte-identical output and follow the same rules below.
The onboarding-template-check workflow enforces parity on every PR.

The helper:

- Resolves the target repo root via `git rev-parse --show-toplevel` (override
  by passing an explicit path as the first argument).
- Copies each template only if the destination does not already exist
  (**skip-with-notice on collision** — never overwrites a customized file).
- Prints `✓ Created` for new files, `⊝ Skipped` for collisions, and a final
  `Created N file(s), skipped M file(s).` summary.
- Leaves all files **unstaged**. It does not run `git add`, `git commit`,
  `git push`, or open a pull request — the user decides how to land them.
- For each skipped file, prints a `diff -u` command pointing at the
  canonical template so the user can reconcile manually.

If the user already had a custom `.github/copilot-instructions.md`, the
scaffold step skips it. Step 10 (below) handles that case explicitly.

### Step 10: Compliance & Azure Policy Preferences

After RBAC and environment setup, ask the user about compliance requirements and update the `## Compliance & Azure Policy` section in `.github/copilot-instructions.md`:

1. **Ask compliance framework:**
   ```
   Which compliance framework should Git-Ape use for policy recommendations?
   - General Azure best practices (recommended)
   - CIS Azure Foundations v3.0
   - NIST SP 800-53 Rev 5
   - None — skip policy recommendations
   ```

2. **Ask enforcement mode:**
   ```
   How should policies be enforced initially?
   - Audit only (recommended — evaluate compliance without blocking)
   - Enforce (Deny — block non-compliant deployments immediately)
   ```

3. **Update `copilot-instructions.md`** with the user's choices:
   - If the file does not exist (scaffold step was skipped or scaffolding
     was not run), print the captured preferences in chat and ask the user
     to add them manually. Do NOT create a new file from scratch — that is
     the scaffold step's responsibility.
   - If the file exists AND contains a `## Compliance & Azure Policy`
     section, edit the `### Compliance Frameworks` and
     `### Policy Enforcement Mode` subsections in place.
   - If the file exists but does NOT contain that section (user has a
     customized file), do NOT mutate it. Instead, print the captured
     preferences and a suggested patch in chat so the user can apply it.
   - In all cases, leave changes unstaged and let the user commit them.

### Step 11: Runner Selection & Provisioning (optional)

Git-Ape workflows resolve their runner from a single variable:

```yaml
runs-on: ${{ vars.GIT_APE_RUNNER_LABEL || 'ubuntu-latest' }}
```

Unset → public GitHub-hosted `ubuntu-latest` (the default; no infrastructure).
Set to a label → private self-hosted runners registered with that label. This is
the **bootstrap model: start public, switch to private later with one variable.**

1. **Ask the runner type:**
   ```
   What runner should the Git-Ape workflows run on?
   - Public GitHub-hosted (recommended to start — no infrastructure)
   - Self-hosted in my Azure subscription
   - VNet-injected (private connectivity, no public egress except to GitHub)
   ```

2. **If public (default):** do nothing. Leave `GIT_APE_RUNNER_LABEL` unset.
   Onboarding is complete; the user can switch to private runners any time by
   repeating this step.

3. **If self-hosted or VNet-injected, ask the platform:**
   ```
   Which Azure platform should host the runners?
   - ACI  — Azure Container Instances (simplest; a handful of runners)
   - ACA  — Azure Container Apps (event-driven, ephemeral, scale-to-zero)
   - AKS  — Azure Kubernetes Service (Actions Runner Controller; large scale)
   ```

4. **Build the custom runner image.** The base `ghcr.io/actions/runner:latest`
   (GitHub's official runner image) does **NOT** include `az`, `gh`, or `jq`.
   Workflows will fail with `Unable to locate executable file: az` without a
   custom image.
   ```bash
   # Create ACR (one-time)
   az acr create --name <acr-name> --resource-group <rg> --location <region> --sku Basic --admin-enabled true

   # Build and push image (runs in Azure, ~3 min, no local Docker needed)
   az acr build --registry <acr-name> --image git-ape-runner:latest \
     --file ./templates/runners/Dockerfile ./templates/runners/
   ```
   The `Dockerfile` at `./templates/runners/Dockerfile` extends the base runner
   with all Git-Ape prerequisites (`az`, `gh`, `jq`, `git`).

5. **Deploy the runner infrastructure** using the chosen platform template.
   Pass the custom image via the `runnerImage` parameter:
   ```bash
   az deployment group create -g <rg> -f template.json \
     -p runnerImage='<acr-name>.azurecr.io/git-ape-runner:latest' \
        githubOwnerRepo='<org>/<repo>' \
        githubAccessToken='<from-keyvault>'
   ```
   - The GitHub registration credential is the only secret — source it from Key
     Vault, never inline it. Azure access uses a user-assigned managed identity.
   - For VNet-injected, set the subnet parameter (`subnetId` for ACI,
     `infrastructureSubnetId` for ACA, or a VNet node pool for AKS).
   - For AKS, use `helm install` instead of ARM.
   - Do NOT add these templates to the scaffold helper — they are on-demand only.

6. **Configure ACR pull credentials** on the ACA/ACI job (if using ACR):
   ```bash
   az containerapp job registry set --name git-ape-runner --resource-group <rg> \
     --server <acr-name>.azurecr.io --username <acr-name> \
     --password $(az acr credential show -n <acr-name> --query "passwords[0].value" -o tsv)
   ```

7. **Set `minExecutions=1`** (recommended) so at least one runner is always
   warm and visible in GitHub Settings. Without this, KEDA scale-from-zero can
   take 1–3 minutes on cold start, during which GitHub shows "No runners
   configured":
   ```bash
   az containerapp job update --name git-ape-runner --resource-group <rg> --min-executions 1
   ```
   Leave at `0` only if you prefer true scale-to-zero and can tolerate cold-start
   delays.

8. **Confirm the runner is online** in *GitHub → Settings → Actions → Runners*
   with the `git-ape-runner` label. (With `minExecutions=1`, a runner should
   appear within 30–60 seconds of deployment.)

9. **Set the variable** so workflows target it (repo-wide or per environment):
   ```bash
   gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --body "git-ape-runner"
   # per environment instead:
   gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --env azure-deploy --body "git-ape-runner"
   ```
   Clean fallback to GitHub-hosted runners is `gh variable delete GIT_APE_RUNNER_LABEL`.

10. **Verify** by triggering `Git-Ape: Verify Setup` and confirming all steps
    pass on the private runner (especially "Test OIDC login" which requires `az`).

11. **Continuous drift detection** (`git-ape-drift.lock.yml`) is a compiled gh-aw
    workflow and does NOT honor `GIT_APE_RUNNER_LABEL`. To move drift onto a
    private runner, set `runs-on:` in the source `git-ape-drift.md` frontmatter
    and recompile with `gh aw compile` — never hand-edit the `.lock.yml` (it
    carries an integrity hash). The other four workflows need no recompile.

## Safe-Execution Rules

1. Echo target repository and subscription(s) before execution.
2. Require explicit user confirmation before running onboarding.
3. Never print secret values in chat output.
4. Summarize what was created or updated (app registration, federated credentials, role assignments, GitHub environments, scaffolded files).
5. If onboarding fails, surface the failing step and command context, then stop.
6. Never overwrite an existing `.github/workflows/*` file or
   `.github/copilot-instructions.md`. The scaffold helper enforces
   skip-with-notice; do not bypass it.
7. Never run `git add`, `git commit`, `git push`, or open a PR for the
   scaffolded files — leave them unstaged so the user decides how to land
   them.

## Suggested Agent Flow

1. **Run `/prereq-check`** to validate tools and auth. Stop if it doesn't report ✅ READY.
2. Confirm target repo URL, onboarding mode, and role model.
3. Validate current Azure/GitHub auth context (subscription, tenant, GitHub org).
4. Ask for final confirmation.
5. Execute the required Azure CLI and GitHub CLI commands directly from this playbook.
6. Scaffold workflow files and `copilot-instructions.md` via `./scripts/scaffold-repo.sh` on macOS/Linux/WSL, or `pwsh ./scripts/scaffold-repo.ps1` on Windows (Step 9 in playbook). Report which files were created vs skipped.
7. Ask compliance framework and enforcement mode preferences (Step 10 in playbook).
8. Update `copilot-instructions.md` with compliance preferences — or, if the file was skipped by the scaffold step, surface the preferences in chat for manual integration.
9. Ask the runner type (and platform if private), and — if private runners are chosen — provision the full stack: ACR + custom image + ACA/ACI deployment + `minExecutions=1` + registry credentials + `GIT_APE_RUNNER_LABEL` (Step 11 in playbook).
10. **Verify** by triggering `Git-Ape: Verify Setup` and confirming ALL steps pass on the private runner.
11. Summarize outcome (including scaffolded file counts and the chosen runner type) and suggest verification commands.

## Known Gotchas

### Default runner image lacks required tools

The base image `ghcr.io/actions/runner:latest` (GitHub's official runner) is a
**minimal** self-hosted runner — it does NOT include `az`, `gh`, or `jq`. If you
deploy without the custom image, workflows will fail with:

```
Error: Unable to locate executable file: az
```

**Fix:** Always build and use the custom image from `./templates/runners/Dockerfile`.
The onboarding flow must:
1. Create an ACR (`az acr create`)
2. Build the image (`az acr build --image git-ape-runner:latest`)
3. Configure pull credentials on the ACA/ACI job (`az containerapp job registry set`)
4. Set the `runnerImage` parameter to the ACR image

### KEDA scale-from-zero cold start

With `minExecutions=0` (the default), KEDA's `github-runner` scaler polls the
GitHub Actions queue every 30 seconds. On a fresh deployment or after long idle
periods, the first job can wait 1–3 minutes before a runner spins up. During
this time:
- GitHub shows the job as "Waiting for a runner to pick up this job"
- The Settings → Runners page shows "No runners configured" (ephemeral runners
  only register while executing)

**Fix:** Set `minExecutions=1` to keep one runner always warm. This costs
~$30–50/month on the Consumption plan but eliminates cold-start delays and
ensures a runner is always visible in GitHub Settings.

### Stale workflow files in target repos

If the target repo was onboarded before the `GIT_APE_RUNNER_LABEL` pattern was
introduced, its workflow files may have hardcoded `runs-on: ubuntu-latest`. The
private runner will never pick up jobs because workflows don't request its label.

**Fix:** The scaffold helper (`scaffold-repo.sh` / `.ps1`) skips existing files.
To update stale workflows, the agent must either:
1. Detect the stale pattern (`grep 'runs-on: ubuntu-latest'`) and offer to
   update all 4 workflow files with the dynamic pattern, OR
2. Advise the user to manually replace `runs-on: ubuntu-latest` with
   `runs-on: ${{ vars.GIT_APE_RUNNER_LABEL || 'ubuntu-latest' }}` in each job.

### GitHub Org Custom OIDC Subject Template (e.g. Azure org)

Some GitHub organizations (notably the `Azure` org) override the default OIDC subject
claim template to use **numeric ID-based** subjects instead of name-based ones.

The skill auto-detects this by calling:
```bash
gh api "orgs/{org}/actions/oidc/customization/sub" --jq ".use_default"
```
- Returns `true` → standard format: `repo:Azure/git-ape:pull_request`
- Returns `false` → ID format: `repository_owner_id:6844498:repository_id:1184905165:pull_request`

If OIDC login fails with `AADSTS700213: No matching federated identity record`, the
federated credential subjects don't match what GitHub is presenting. Fix by re-running
onboarding (the skill will auto-detect and use the correct format), or manually updating
existing credentials:
```bash
# Get repo/owner IDs
gh api repos/Azure/git-ape --jq '{repo_id: .id, owner_id: .owner.id}'

# Update each federated credential with correct subject
az ad app federated-credential update \
  --id <APP_OBJECT_ID> \
  --federated-credential-id <CRED_ID> \
  --parameters '{"subject":"repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>:pull_request"}'
```

### Disabled Subscriptions

Azure subscriptions in a `Disabled` state are read-only — RBAC assignments will fail.
Verify subscription state before onboarding:
```bash
az account show --subscription <SUB_ID> --query "{name:name,state:state}" -o table
# Test write access:
az group list --subscription <SUB_ID> --query "length(@)" -o tsv
```

## Verification Commands

```bash
# Azure context
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table

# GitHub auth
gh auth status

# Validate app federated credentials — check subjects match org OIDC format
az ad app federated-credential list --id <APP_OBJECT_ID> -o json | jq -r '.[] | "\(.name): \(.subject)"'

# Check GitHub org OIDC subject template (true = name-based, false = ID-based)
gh api orgs/<ORG>/actions/oidc/customization/sub --jq '.use_default'

# Get repo and owner numeric IDs (needed for ID-based subject construction)
gh api repos/<ORG>/<REPO> --jq '{repo_id: .id, owner_id: .owner.id}'

# Validate role assignments for SP (replace principal object id)
az role assignment list --assignee-object-id <SP_OBJECT_ID> --all -o table
```