---
title: "Git Ape Onboarding"
sidebar_label: "Git Ape Onboarding"
description: "Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets."
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-onboarding/SKILL.md -->


# Git Ape Onboarding

> Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets.

## Details

| Property | Value |
|----------|-------|
| **Skill Directory** | `.github/skills/git-ape-onboarding/` |
| **Phase** | Operations |
| **User Invocable** | ✅ Yes |
| **Usage** | `/git-ape-onboarding GitHub repo URL, subscription target(s), and onboarding mode (single or multi-environment)` |


## Documentation

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
5. Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

## Prerequisites

Before onboarding, run the **prereq-check** skill to verify all required tools are installed and auth sessions are active:

```text
/prereq-check
```

The prereq-check skill validates: `az` (≥ 2.50), `gh` (≥ 2.0), `jq` (≥ 1.6), `git`, and active Azure/GitHub auth sessions. If anything is missing, it shows platform-specific install commands.

Do NOT proceed with onboarding until prereq-check reports **✅ READY**.

Additionally, the Azure identity used must have **Owner** or **User Access Administrator** on the target subscription(s), and the GitHub identity must have **admin** access to the target repository.

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
5. Create federated credentials for `main`, `pull_request`, `azure-deploy*`, and `azure-destroy`.
6. Assign RBAC on each target subscription.
7. Set GitHub repo or environment secrets.
8. Create GitHub environments and branch policies when permissions allow.
9. Capture compliance and Azure Policy preferences (see below).
10. Collect explicit acknowledgments for experimental status and production safety.
11. Activate workflows by renaming `.exampleyml` to `.yml` (only if all acknowledgments confirmed; see Step 11 section below).
12. Verify federated credentials, role assignments, secrets, and workflow activation.

### Step 9: Compliance & Azure Policy Preferences

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
   - Edit the `## Compliance & Azure Policy` → `### Compliance Frameworks` section
   - Set the `### Policy Enforcement Mode` default to the user's choice
   - Commit the update as part of the onboarding changes

### Step 11: Activate GitHub Workflows

After collecting acknowledgments for experimental status and production safety (see agent's "Acknowledgment Phase"), activate the Git-Ape workflows by renaming `.exampleyml` files to `.yml` in the `.github/workflows/` directory.

**Files to activate:**
- `git-ape-plan.exampleyml` → `git-ape-plan.yml` (validates template and shows what-if)
- `git-ape-deploy.exampleyml` → `git-ape-deploy.yml` (executes deployments)
- `git-ape-destroy.exampleyml` → `git-ape-destroy.yml` (tears down resources)
- `git-ape-verify.exampleyml` → `git-ape-verify.yml` (runs verification steps)

**Rename commands (Unix/macOS/Linux):**
```bash
cd .github/workflows
for f in *.exampleyml; do
  target="${f%.exampleyml}.yml"
  mv "$f" "$target"
  echo "Renamed: $f -> $target"
done
```

**Rename commands (Windows PowerShell):**
```powershell
cd .github\workflows
Get-ChildItem *.exampleyml | ForEach-Object {
  $newName = $_.Name -replace '\.exampleyml$', '.yml'
  Rename-Item -Path $_.FullName -NewName $newName
  Write-Host "Renamed: $($_.Name) -> $newName"
}
```

**Verification (all platforms):**
```bash
ls .github/workflows/git-ape-*.yml
```

Should output:
```
git-ape-deploy.yml
git-ape-destroy.yml
git-ape-plan.yml
git-ape-verify.yml
```

**Output after activation:**
Display summary:
```
✅ Workflows activated:
  - git-ape-plan.yml (validates and plans deployments)
  - git-ape-deploy.yml (executes deployments and integration tests)
  - git-ape-destroy.yml (tears down resources when requested)
  - git-ape-verify.yml (runs post-deployment verification)

Next steps:
1. Review .github/workflows/git-ape-*.yml for familiarity
2. Push changes to a feature branch and open a PR
3. Verify the plan workflow runs and shows what-if analysis in the PR comment
4. For first deployment, merge to main and monitor git-ape-deploy.yml execution
```

## Safe-Execution Rules

1. Echo target repository and subscription(s) before execution.
2. Require explicit user confirmation before running onboarding.
3. Never print secret values in chat output.
4. **Require explicit acknowledgments before activating workflows** — User must confirm Git-Ape is experimental, will review plans, and won't deploy to production.
5. **Only activate workflows if ALL acknowledgments are confirmed** — Renaming happens only after explicit "Yes" to all three questions.
6. If user refuses any acknowledgment, complete onboarding but skip workflow activation. User can enable later manually.
7. Summarize what was created or updated (app registration, federated credentials, role assignments, GitHub environments, workflows activated).
8. If onboarding fails, surface the failing step and command context, then stop.

## Suggested Agent Flow

1. **Run `/prereq-check`** to validate tools and auth. Stop if it doesn't report ✅ READY.
2. Confirm target repo URL, onboarding mode, and role model.
3. Validate current Azure/GitHub auth context (subscription, tenant, GitHub org).
4. Ask for final confirmation.
5. Execute the required Azure CLI and GitHub CLI commands directly from this playbook (Steps 1-8).
6. Ask compliance framework and enforcement mode preferences (Step 9 in playbook).
7. Update `copilot-instructions.md` with compliance preferences.
8. **Display experimental warning and collect acknowledgments** (three explicit "Yes" answers required).
9. If all acknowledgments confirmed, execute workflow activation (Step 11 in playbook).
10. If any acknowledgment refused, skip workflow activation (workflows remain `.exampleyml`).
11. Summarize outcome, activated workflows (if any), and suggest verification commands.

## Known Gotchas

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
