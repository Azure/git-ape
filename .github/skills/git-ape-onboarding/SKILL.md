---
name: git-ape-onboarding
description: "Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets."
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

### Parameterized with CI/CD provider selection

The `cicd <provider>` segment selects which CI/CD primitives are configured. Valid providers: `github` (default), `ado`, `both`. ADO and Both require `org=<ado-org-url>` and `project=<ado-project>`.

```text
# Azure DevOps Pipelines, Azure Repos backend
/git-ape-onboarding cicd ado on https://dev.azure.com/contoso project=infra subscription=00000000-0000-0000-0000-000000000000

# Both — GitHub Actions and Azure DevOps Pipelines, GitHub-backed source
/git-ape-onboarding cicd both on https://github.com/contoso/repo org=https://dev.azure.com/contoso project=infra subscription=00000000-0000-0000-0000-000000000000
```

When `cicd` is omitted, the agent prompts via `vscode_askQuestions` (see the agent's "CI/CD Platform Selection" section).

## Command Playbook

When the agent executes this skill, it should run the equivalent Azure and GitHub CLI commands directly in this order. Each step is annotated **[shared]**, **[github]**, or **[ado]**:

* **[shared]** — runs for every provider selection.
* **[github]** — runs only when provider is `github` or `both`.
* **[ado]** — runs only when provider is `ado` or `both`.

When provider is `both`, run the GitHub branch first, then the ADO branch, before moving to the next numbered step.

1. **[shared]** Validate prerequisites and current auth context. When provider is `ado` or `both`, the prereq check must also confirm the `azure-devops` extension and a reachable ADO org (see `/prereq-check`).
2. Resolve repo metadata.
   - **[github]**:
     ```bash
     gh repo view <org>/<repo>
     gh api repos/<org>/<repo> --jq '{repo_id: .id, owner_id: .owner.id}'
     gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
     ```
   - **[ado]**:
     ```bash
     az devops project show --project "$ADO_PROJECT" --org "$ADO_ORG_URL" \
       --query "{id:id,name:name,visibility:visibility}" -o table
     # Resolve the org GUID — required for federated subjects in some flows
     ADO_ORG_NAME=$(echo "$ADO_ORG_URL" | sed -E 's|https?://dev\.azure\.com/||; s|/$||')
     curl -sSf "https://dev.azure.com/${ADO_ORG_NAME}/_apis/connectionData?api-version=7.1" \
       -H "Authorization: Bearer $(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)" \
       | jq -r '.instanceId'
     ```
3. **[shared]** Create or reuse the Entra app registration and service principal:
```bash
CLIENT_ID=$(az ad app create --display-name "$SP_NAME" --query appId -o tsv)
az ad sp create --id "$CLIENT_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)
OBJECT_ID=$(az ad app show --id "$CLIENT_ID" --query id -o tsv)
```
4. Build the OIDC subject prefix.
   - **[github]**:
     ```bash
     # default format
     OIDC_PREFIX="repo:<org>/<repo>"

     # if org customization returns false
     OIDC_PREFIX="repository_owner_id:<OWNER_ID>:repository_id:<REPO_ID>"
     ```
   - **[ado]**: subject is deterministic per service connection — no claim-template detection required:
     ```bash
     # One subject per service connection (one connection per env in multi-env mode)
     ADO_SUBJECT="sc://${ADO_ORG_NAME}/${ADO_PROJECT}/${ADO_CONNECTION_NAME}"
     ADO_ISSUER="https://vstoken.dev.azure.com/${ADO_ORG_GUID}"
     ADO_AUDIENCE="api://AzureADTokenExchange"
     ```
5. Create federated credentials.
   - **[github]**: per-branch and per-environment subjects (`refs/heads/main`, `pull_request`, `environment:azure-deploy*`, `environment:azure-destroy`).
   - **[ado]**: one federated credential per service connection. For multi-environment mode, create one service connection per environment (e.g. `git-ape-azure-dev`, `git-ape-azure-staging`, `git-ape-azure-prod`) and register one federated credential for each. Workload identity federation is the only supported auth path — never create or store PATs, client secrets, or password credentials for the ADO service connection.
6. **[shared]** Assign RBAC on each target subscription.
7. Set CI/CD secrets — values are non-secret identifiers, but the API names matter.
   - **[github]**:
     ```bash
     gh secret set AZURE_CLIENT_ID --env azure-deploy --body "$CLIENT_ID"
     gh secret set AZURE_TENANT_ID --env azure-deploy --body "$TENANT_ID"
     gh secret set AZURE_SUBSCRIPTION_ID --env azure-deploy --body "$SUBSCRIPTION_ID"
     ```
   - **[ado]**: store identifiers in a variable group; do not store any secret values (no PATs, no client secrets):
     ```bash
     VG_ID=$(az pipelines variable-group create \
       --name git-ape-azure-secrets \
       --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
       --variables AZURE_CLIENT_ID="$CLIENT_ID" AZURE_TENANT_ID="$TENANT_ID" AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
       --authorize true \
       --query id -o tsv)

     # Mark each variable as secret-flagged (values are still identifiers, not credentials)
     for var in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID; do
       az pipelines variable-group variable update \
         --group-id "$VG_ID" --name "$var" --secret true \
         --org "$ADO_ORG_URL" --project "$ADO_PROJECT"
     done
     ```
8. Create deployment environments and approval gates.
   - **[github]**:
     ```bash
     gh api repos/<org>/<repo>/environments/azure-deploy --method PUT
     gh api repos/<org>/<repo>/environments/azure-destroy --method PUT
     ```
   - **[ado]**: ADO has no first-class CLI for environments; use `az devops invoke` against the `distributedtask` area, then attach approval checks via the same area:
     ```bash
     ENV_ID=$(az devops invoke \
       --area distributedtask --resource environments \
       --route-parameters project="$ADO_PROJECT" \
       --http-method POST --in-file <(printf '{"name":"azure-deploy","description":"Git-Ape deploy environment"}') \
       --org "$ADO_ORG_URL" --query id -o tsv)

     # Add approval check (replace <APPROVER_DESCRIPTOR> with az devops user show output)
     az devops invoke \
       --area distributedtask --resource configurations \
       --route-parameters project="$ADO_PROJECT" \
       --http-method POST \
       --in-file <(printf '{"type":{"name":"Approval"},"resource":{"type":"environment","id":"%s"},"settings":{"approvers":[{"id":"<APPROVER_DESCRIPTOR>"}],"executionOrder":1,"minRequiredApprovers":1}}' "$ENV_ID") \
       --org "$ADO_ORG_URL"
     ```
9. **[shared]** Capture compliance and Azure Policy preferences (see Step 9 below).
10. **[shared]** Collect explicit acknowledgments for experimental status and production safety. The acknowledgment gate is identical for both providers (see the agent's "Acknowledgment Phase").
11. Activate workflows by renaming examples to active files (only if all acknowledgments confirmed).
   - **[github]**: rename `.github/workflows/*.exampleyml` → `*.yml` (see Step 11 section below).
   - **[ado]**: rename `.azure-pipelines/*.examplepipeline.yml` → `*.yml`, then register each pipeline with `az pipelines create`. See the ADO branch in Step 11 below.
   - **[ado]** Step 11c: grant the project's build identity Contribute on the repo so deploy/destroy pipelines can push `state.json` and `metadata.json` via `$(System.AccessToken)` without a PAT (see Step 11c below).
   - **[both]**: run the GitHub branch first, then the ADO branch, then Step 11c.
12. **[shared]** Verify federated credentials, role assignments, secrets, and workflow activation.

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

### Step 11: Activate CI/CD Workflows

After collecting acknowledgments for experimental status and production safety (see agent's "Acknowledgment Phase"), activate the Git-Ape workflows for the selected provider(s).

#### Step 11a — GitHub Actions branch [github]

Activate the four Git-Ape workflows by renaming `.exampleyml` files to `.yml` in `.github/workflows/`.

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

#### Step 11b — Azure DevOps Pipelines branch [ado]

Activate the four Git-Ape pipelines by renaming `.examplepipeline.yml` files to `.yml` in `.azure-pipelines/`, then register each with `az pipelines create`.

**Files to activate:**
- `git-ape-plan.examplepipeline.yml` → `git-ape-plan.yml`
- `git-ape-deploy.examplepipeline.yml` → `git-ape-deploy.yml`
- `git-ape-destroy.examplepipeline.yml` → `git-ape-destroy.yml`
- `git-ape-verify.examplepipeline.yml` → `git-ape-verify.yml`

**Rename commands (Unix/macOS/Linux):**
```bash
cd .azure-pipelines
for f in *.examplepipeline.yml; do
  target="${f%.examplepipeline.yml}.yml"
  mv "$f" "$target"
  echo "Renamed: $f -> $target"
done
```

**Register each pipeline:**
```bash
for name in git-ape-plan git-ape-deploy git-ape-destroy git-ape-verify; do
  az pipelines create \
    --name "$name" \
    --yaml-path ".azure-pipelines/${name}.yml" \
    --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
    --repository "$ADO_REPO_NAME" \
    --repository-type "$ADO_REPO_TYPE" \
    --branch main \
    --skip-first-run true
done
```

`$ADO_REPO_TYPE` is `tfsgit` for Azure Repos or `github` when the source repo is a GitHub-hosted repo (Both mode). For GitHub-backed repos, `--service-connection <github-service-connection>` is also required.

**Note:** ADO pipelines use `strategy: matrix:` from a runtime variable (computed by an earlier job that detects changed deployments) instead of GitHub's `strategy.matrix` over a JSON list. This keeps the per-deployment shape comparable to the GitHub workflows while staying within ADO's templating model.

#### Step 11c — Grant build identity Contribute on the repo [ado]

The ADO deploy and destroy pipelines push `state.json` and `metadata.json` back to the repo using `$(System.AccessToken)`. Without this grant, the pipelines fail on push with `TF401027: You need the Git 'GenericContribute' permission`. Workload identity federation does not cover repo-write operations performed by the build identity.

```bash
# Resolve the project's build identity descriptor
PROJECT_ID=$(az devops project show --project "$ADO_PROJECT" --org "$ADO_ORG_URL" --query id -o tsv)
BUILD_IDENTITY="Project Collection Build Service (${ADO_ORG_NAME})"
SUBJECT_DESCRIPTOR=$(az devops user show --user "$BUILD_IDENTITY" --org "$ADO_ORG_URL" --query "user.descriptor" -o tsv 2>/dev/null \
  || az devops invoke --area identities --resource identities --route-parameters identityIds= \
       --query-parameters searchFilter=DisplayName filterValue="$BUILD_IDENTITY" \
       --org "$ADO_ORG_URL" --query "value[0].subjectDescriptor" -o tsv)

# Resolve the Git Repositories namespace and the Contribute bit
GIT_NAMESPACE_ID=$(az devops security permission namespace list --org "$ADO_ORG_URL" \
  --query "[?name=='Git Repositories'].namespaceId | [0]" -o tsv)
CONTRIBUTE_BIT=$(az devops security permission namespace show --namespace-id "$GIT_NAMESPACE_ID" --org "$ADO_ORG_URL" \
  --query "[0].actions[?name=='GenericContribute' || name=='Contribute'] | [0].bit" -o tsv)

# Repo-scoped token: repoV2/<projectId>/<repositoryId>
REPO_ID=$(az repos show --repository "$ADO_REPO_NAME" --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)
TOKEN="repoV2/${PROJECT_ID}/${REPO_ID}"

az devops security permission update \
  --namespace-id "$GIT_NAMESPACE_ID" \
  --subject "$SUBJECT_DESCRIPTOR" \
  --token "$TOKEN" \
  --allow-bit "$CONTRIBUTE_BIT" \
  --org "$ADO_ORG_URL"
```

**Skip Step 11c when:** the source repo lives in a different ADO project than the pipeline. In that case the cross-project build identity grant cannot be issued from the project's own scope; document the manual portal grant instead and surface a `⚠️ MANUAL ACTION REQUIRED` line in the onboarding summary.

Reference: [Azure DevOps CLI security permission](https://learn.microsoft.com/azure/devops/cli/security/permission).

#### Step 11 output

Display a summary of activated artifacts for the chosen provider(s):

```
✅ Workflows activated:
  GitHub Actions:                            (when github or both)
    - git-ape-plan.yml
    - git-ape-deploy.yml
    - git-ape-destroy.yml
    - git-ape-verify.yml
  Azure DevOps Pipelines:                    (when ado or both)
    - git-ape-plan.yml
    - git-ape-deploy.yml
    - git-ape-destroy.yml
    - git-ape-verify.yml
    Build identity Contribute grant: ✅ applied | ⚠️ manual

Next steps:
1. Review the activated CI/CD definitions for familiarity
2. Push changes to a feature branch and open a PR
3. Verify the plan workflow/pipeline runs and posts what-if analysis on the PR
4. For first deployment, merge to main and monitor the deploy workflow/pipeline
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

### Azure DevOps — provider-specific gotchas

- **No `issue_comment` trigger.** ADO pipelines cannot trigger from PR comments. The GitHub `/deploy` early-deploy comment trigger has no ADO equivalent — deploy gating relies entirely on the `azure-deploy` environment's pre-deployment approval check.
- **Federated subject is per-connection, not per-branch.** ADO workload identity federation issues a token whose subject is `sc://<org>/<project>/<connection>`. There is no per-branch or per-environment subject; isolate environments by creating one service connection (and one federated credential) per environment.
- **No SARIF upload.** GitHub Code Scanning (SARIF) does not exist on ADO. The verify pipeline publishes a verification report as a pipeline artifact instead. Do not attempt to upload SARIF from ADO.
- **Build identity needs explicit Contribute on the repo.** Workload identity federation does not cover repo-write operations performed by `$(System.AccessToken)`. Step 11c grants this; skip only when the source repo lives in a different ADO project (then document the manual portal grant).
- **Workload identity federation only.** Never create or store PATs, client secrets, or password credentials for the Git-Ape ADO service connection. If a step appears to require a PAT, surface a blocker rather than introducing one.

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