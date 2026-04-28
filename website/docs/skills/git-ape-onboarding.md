<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/skills/git-ape-onboarding/SKILL.md -->

---
title: "Git Ape Onboarding"
sidebar_label: "Git Ape Onboarding"
description: "Onboard a repository, Azure subscription(s), and user identity for Git-Ape CI/CD using a skill-driven CLI playbook. Use for first-time setup of OIDC, federated credentials, RBAC, GitHub environments, and required secrets."
---

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

## Architecture: Orchestrator + Sub-skills

This is the **orchestrator** skill. It runs the cross-cutting setup (App Registration, federated credentials, RBAC, secrets, environments) for whichever provider(s) the user picks via `cicd: github | ado | both`. For provider-specific final activation, it dispatches to:

| Provider | Sub-skill | Handles |
|---|---|---|
| GitHub Actions | [`git-ape-onboarding-github`](./git-ape-onboarding-github) | Workflow rename, verify workflow trigger, GitHub-specific gotchas (org OIDC subject template, environment secrets, PR comment permissions) |
| Azure DevOps | [`git-ape-onboarding-azdo`](./git-ape-onboarding-azdo) | Pipeline registration, build identity ACL grant (allow=16516), Branch Policy required check, parallelism quota verification |

**Why split.** ADO has substantially more provider-specific knowledge (ACL bits, branch policies, `pr:` ignored, `$(macro)` in bash, `PublishPipelineArtifact@1` ordering, parallelism quota) than fits cleanly inline. The sub-skill keeps that complexity isolated and lets ADO learnings evolve without churning the GitHub flow.

## What It Configures

This skill configures:

1. Entra ID App Registration and service principal (or reuses existing)
2. OIDC federated credentials for GitHub Actions
3. RBAC role assignment(s) on subscription scope
4. GitHub environments (`azure-deploy*`, `azure-destroy`)
5. Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

## Prerequisites

**Auto-Installation Approach:** The onboarding agent now automatically installs missing prerequisites instead of just detecting them.

**Required tools:**
- `az` (≥ 2.50) — Azure CLI
- `gh` (≥ 2.0) — GitHub CLI
- `jq` (≥ 1.6) — JSON processor
- `git` — Version control
- `azure-devops` extension — For Azure DevOps operations

**Auto-installation commands by platform:**

**Windows (PowerShell):**
```powershell
# Install missing tools automatically
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  winget install jqlang.jq
}
if (-not (az extension show --name azure-devops 2>$null)) {
  az extension add --name azure-devops
}
```

**macOS/Linux (bash):**
```bash
# Install missing tools automatically
command -v jq >/dev/null 2>&1 || {
  if command -v brew >/dev/null 2>&1; then
    brew install jq
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y jq
  fi
}
az extension show --name azure-devops >/dev/null 2>&1 || az extension add --name azure-devops
```

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

1. **[shared]** Auto-install missing prerequisites and validate auth context:
   ```bash
   # Auto-install prerequisites (Windows PowerShell example)
   if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
     Write-Host "Installing jq..."
     winget install jqlang.jq
   }
   if (-not (az extension show --name azure-devops 2>$null)) {
     Write-Host "Installing azure-devops extension..."
     az extension add --name azure-devops
   }
   
   # Enhanced Azure DevOps access validation
   if provider is ado or both:
     az devops user show --org "$ADO_ORG_URL" --query "user.displayName" -o tsv || {
       echo "❌ Azure DevOps access required. Please:"
       echo "1. Visit: $ADO_ORG_URL"
       echo "2. Sign in with your Azure account"
       echo "3. Retry onboarding"
       exit 1
     }
   ```
2. Resolve repo metadata.
   - **[github]**:
     ```bash
     gh repo view <org>/<repo>
     gh api repos/<org>/<repo> --jq '{repo_id: .id, owner_id: .owner.id}'
     gh api orgs/<org>/actions/oidc/customization/sub --jq '.use_default'
     ```
   - **[ado]**:
     ```bash
     # Validate project access and get details
     az devops project show --project "$ADO_PROJECT" --org "$ADO_ORG_URL" \
       --query "{id:id,name:name,visibility:visibility}" -o table
     
     # Dynamic repository detection (don't assume repo names)
     ADO_REPO_NAME=$(az repos list --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
       --query "[0].name" -o tsv)
     echo "Detected repository: $ADO_REPO_NAME"
     
     # Resolve the org GUID — required for federated subjects
     ADO_ORG_NAME=$(echo "$ADO_ORG_URL" | sed -E 's|https?://dev\.azure\.com/||; s|/$||')
     ADO_ORG_GUID=$(curl -sSf "https://dev.azure.com/${ADO_ORG_NAME}/_apis/connectionData?api-version=7.1" \
       -H "Authorization: Bearer $(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)" \
       | jq -r '.instanceId')
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
   - **[ado]**: **Do NOT hardcode the issuer/subject.** The conventional `vstoken.dev.azure.com` issuer and `sc://` subject format do NOT match what ADO actually presents to Entra ID. Instead, create the service connection first (Step 7a), then read back the actual OIDC details:
     ```bash
     # After creating the service connection (Step 7a), read back actual OIDC values:
     ADO_TOKEN=$(az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
     SC_DETAILS=$(curl -sSf \
       -H "Authorization: Bearer $ADO_TOKEN" \
       "https://dev.azure.com/${ADO_ORG_NAME}/${ADO_PROJECT}/_apis/serviceendpoint/endpoints/${SC_ID}?api-version=7.1")
     ADO_ISSUER=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationIssuer')
     ADO_SUBJECT=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationSubject')
     ADO_AUDIENCE="api://AzureADTokenExchange"
     # Typical actual values:
     #   Issuer:  https://login.microsoftonline.com/<tenant-id>/v2.0
     #   Subject: /eid1/c/pub/t/<base64>/a/<base64>/sc/<org-guid>/<connection-id>
     ```
     ADO_ISSUER=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationIssuer')
     ADO_SUBJECT=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationSubject')
     ADO_AUDIENCE="api://AzureADTokenExchange"
     # Typical actual values:
     #   Issuer:  https://login.microsoftonline.com/<tenant-id>/v2.0
     #   Subject: /eid1/c/pub/t/<base64>/a/<base64>/sc/<org-guid>/<connection-id>
     ```
     ADO_ISSUER=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationIssuer')
     ADO_SUBJECT=$(echo "$SC_DETAILS" | jq -r '.authorization.parameters.workloadIdentityFederationSubject')
     ADO_AUDIENCE="api://AzureADTokenExchange"
     # Typical actual values:
     #   Issuer:  https://login.microsoftonline.com/<tenant-id>/v2.0
     #   Subject: /eid1/c/pub/t/<base64>/a/<base64>/sc/<org-guid>/<connection-id>
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
   - **[ado]**: store identifiers in a variable group; do not store any secret values (no PATs, no client secrets). Default name `git-ape-azure-secrets` — override via `ADO_VARIABLE_GROUP` if required:
     ```bash
     ADO_VARIABLE_GROUP="${ADO_VARIABLE_GROUP:-git-ape-azure-secrets}"
     VG_ID=$(az pipelines variable-group create \
       --name "$ADO_VARIABLE_GROUP" \
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
7a. **[ado]** Auto-create service connection via REST API (eliminates manual steps):
     ```bash
     # Create service connection JSON configuration
     SERVICE_CONNECTION_JSON=$(cat <<EOF
{
  "name": "$ADO_CONNECTION_NAME",
  "type": "AzureRM",
  "authorization": {
    "parameters": {
      "tenantid": "$TENANT_ID",
      "serviceprincipalid": "$CLIENT_ID"
    },
    "scheme": "WorkloadIdentityFederation"
  },
  "data": {
    "subscriptionId": "$SUBSCRIPTION_ID",
    "subscriptionName": "$(az account show --subscription "$SUBSCRIPTION_ID" --query name -o tsv)",
    "environment": "AzureCloud",
    "scopeLevel": "Subscription",
    "creationMode": "Manual"
  },
  "isShared": false,
  "isReady": true
}
EOF
)
     
     # Create service connection via REST API
     echo "$SERVICE_CONNECTION_JSON" | az devops invoke \
       --area serviceendpoint --resource endpoints \
       --route-parameters project="$ADO_PROJECT" \
       --http-method POST --in-file /dev/stdin \
       --org "$ADO_ORG_URL" --query "name" -o tsv
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
12. **[shared]** Comprehensive end-to-end verification and testing:

```bash
# Verify Azure setup
echo "🔍 Verifying Azure configuration..."
az account show --query "{name:name,id:id,tenantId:tenantId}" -o table
az role assignment list --assignee "$CLIENT_ID" --scope "/subscriptions/$SUBSCRIPTION_ID" -o table

# Verify federated credentials
echo "🔍 Verifying OIDC federated credentials..."
az ad app federated-credential list --id "$OBJECT_ID" -o json | jq -r '.[] | "\(.name): \(.subject)"'

# GitHub-specific verification
if [[ "$PROVIDER" == "github" || "$PROVIDER" == "both" ]]; then
  echo "🔍 Verifying GitHub configuration..."
  gh auth status
  gh api "orgs/$GITHUB_ORG/actions/oidc/customization/sub" --jq '.use_default'
fi

# Azure DevOps-specific verification
if [[ "$PROVIDER" == "ado" || "$PROVIDER" == "both" ]]; then
  echo "🔍 Verifying Azure DevOps configuration..."
  
  # Test service connection
  az devops service-endpoint list --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
    --query "[?name=='$ADO_CONNECTION_NAME'].{name:name,type:type,isReady:isReady}" -o table
  
  # Verify pipelines created
  az pipelines list --org "$ADO_ORG_URL" --project "$ADO_PROJECT" \
    --query "[?starts_with(name,'git-ape-')].{name:name,id:id,status:status}" -o table
  
  # Test connectivity with a simple Azure CLI command through service connection
  echo "🧪 Testing service connection..."
  # This would be part of the pipeline test, not CLI test
  echo "Service connection test requires running a pipeline"
fi

# Final summary
echo "✅ Git-Ape onboarding verification complete!"
echo "📋 Next steps:"
echo "  1. Create a test deployment in .azure/deployments/"
echo "  2. Push changes and verify pipelines trigger"
echo "  3. Monitor first deployment execution"
```

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

Workflow activation is handled by the **`git-ape-onboarding-github` sub-skill** (see [.github/skills/git-ape-onboarding-github/SKILL.md](./git-ape-onboarding-github)).

**Dispatch instruction for the agent:** load and execute that sub-skill's Step A. It expects:

- `GITHUB_REPO` (e.g. `contoso/myapp-infra`) — from Step 1 (resolve metadata)
- `GITHUB_ORG` — from Step 1

The sub-skill performs:
- **Step A**: Activate the four workflows (rename `.exampleyml` → `.yml`)
- **Step B**: Run setup verification (executed via Step 12a below)

It returns a status summary that this orchestrator merges into Step 11 output.

#### Step 11b — Azure DevOps Pipelines branch [ado]

The ADO-specific activation, build identity ACL grant, branch policy creation, and parallelism quota check are all handled by the **`git-ape-onboarding-azdo` sub-skill** (see [.github/skills/git-ape-onboarding-azdo/SKILL.md](./git-ape-onboarding-azdo)).

**Dispatch instruction for the agent:** load and execute that sub-skill end-to-end. It expects the following env vars / values from this orchestrator:

- `ADO_ORG_NAME`, `ADO_ORG_URL`, `ADO_PROJECT`, `ADO_REPO_NAME`, `ADO_REPO_TYPE` — from Step 1 (resolve metadata)
- `ADO_CONNECTION_NAME` — from Step 7a (service connection create); defaults to `git-ape-azure`
- `ADO_VARIABLE_GROUP` — from Step 7 (variable group create); defaults to `git-ape-azure-secrets`
- `ADO_TOKEN` — `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv`

The sub-skill performs:
- **Step A**: Activate pipelines (rename + register)
- **Step B**: Grant build identity 3 Git permissions (allow=16516)
- **Step C**: Create the Branch Policy required check (`Build Validation` on plan pipeline)
- **Step D**: Verify ADO parallelism quota (warn if free-tier 1 job)

It returns a status summary that this orchestrator merges into Step 11 output.

**Why a sub-skill:** the ADO playbook has more provider-specific knowledge (build identity ACLs, branch policies, parallelism quota, `pr:` trigger gotcha, etc.) than fits cleanly inline. Keeping it separate lets ADO-only learnings evolve without touching the GitHub flow.

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

### Step 12: Run setup verification

After activation, trigger the `git-ape-verify` workflow/pipeline once to confirm OIDC, RBAC, and Azure deploy permissions actually work end-to-end. This is a read-only smoke test (no resources are created). It must pass before the user is told onboarding is complete.

#### Step 12a — GitHub Actions branch [github]

Uses **Step B of `git-ape-onboarding-github`** (`gh workflow run git-ape-verify.yml`, then poll). See [.github/skills/git-ape-onboarding-github/SKILL.md](./git-ape-onboarding-github) → "Step B — Run setup verification" for the full command sequence and exit conditions.

#### Step 12b — Azure DevOps Pipelines branch [ado]

Trigger via `az pipelines run`, poll for completion, surface the result:

```bash
VERIFY_PIPELINE_ID=$(az pipelines show --name git-ape-verify \
  --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)

RUN_ID=$(az pipelines run --id "$VERIFY_PIPELINE_ID" --branch main \
  --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query id -o tsv)

# Poll until completion (verify pipeline is fast — read-only checks only)
for i in $(seq 1 60); do
  STATUS=$(az pipelines runs show --id "$RUN_ID" \
    --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query status -o tsv)
  [[ "$STATUS" == "completed" ]] && break
  sleep 10
done

VERIFY_STATUS=$(az pipelines runs show --id "$RUN_ID" \
  --org "$ADO_ORG_URL" --project "$ADO_PROJECT" --query result -o tsv)
VERIFY_URL="${ADO_ORG_URL}/${ADO_PROJECT}/_build/results?buildId=${RUN_ID}"
```

#### Step 12 output

Surface the verification result in the onboarding summary:

```
🔍 Setup verification (git-ape-verify):
  Status: ✅ succeeded | ❌ failed | ⏱ timed out
  Run:    {VERIFY_URL}
```

**Exit conditions:**
- `succeeded` → onboarding is complete; tell the user they can open their first deployment PR
- `failed` → STOP. Print the failed steps from the run log and ask the user to inspect (commonly: missing RBAC role on subscription, federated credential subject mismatch, variable group not linked to pipeline)
- `timed out` (>10 min) → STOP. The pipeline likely never started — check that an agent in pool `Default` (ADO) or a runner (GitHub) is online

Do NOT mark onboarding as complete unless `VERIFY_STATUS == succeeded`.

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
11. Run setup verification (Step 12 in playbook) — trigger `git-ape-verify`, wait for completion, gate "onboarding complete" on its success.
12. Summarize outcome, activated workflows, and verification result.

## Known Gotchas

### GitHub Actions — provider-specific gotchas

The full GitHub gotchas list (custom OIDC subject template, federated credential subjects, `permissions:` block, env vs repo secrets, PR comment permissions, Coding Agent flow) lives in the **`git-ape-onboarding-github` sub-skill**. See [.github/skills/git-ape-onboarding-github/SKILL.md](./git-ape-onboarding-github) → "Provider-specific gotchas (GitHub)".

The most important one the orchestrator needs to know about for cross-cutting flows:

- **Custom org OIDC subject template** (e.g. the `Azure` org). Step 1 must call `gh api orgs/$GITHUB_ORG/actions/oidc/customization/sub --jq '.use_default'` and adapt the federated credential subject format accordingly. Failure mode is `AADSTS700213: No matching federated identity record` at first runtime use.

### Disabled Subscriptions

Azure subscriptions in a `Disabled` state are read-only — RBAC assignments will fail.
Verify subscription state before onboarding:
```bash
az account show --subscription <SUB_ID> --query "{name:name,state:state}" -o table
# Test write access:
az group list --subscription <SUB_ID> --query "length(@)" -o tsv
```

### Azure DevOps — provider-specific gotchas

The full ADO gotchas list (build identity ACL, branch policy `pr:` ignored, `$(macro)` in bash, `PublishPipelineArtifact@1` ordering, parallelism quota, `UsePythonVersion@0` self-hosted limitation, etc.) lives in the **`git-ape-onboarding-azdo` sub-skill**. See [.github/skills/git-ape-onboarding-azdo/SKILL.md](./git-ape-onboarding-azdo) → "Provider-specific gotchas (ADO)".

The most important ones the orchestrator needs to know about for cross-cutting flows:

- **Workload identity federation only.** Never create or store PATs, client secrets, or password credentials for the Git-Ape ADO service connection. If a step appears to require a PAT, surface a blocker rather than introducing one.
- **Federated subject is NOT `sc://` format.** When creating the federated credential in Step 4, **do not hardcode** the issuer/subject — read them back from the service connection endpoint after Step 7a creates it.
- **Build identity needs `allow=16516`.** The ADO sub-skill's Step B grants this. Without it, the deploy/destroy pipelines silently fail to push state or post PR comments.
- **YAML `pr:` triggers are ignored** for Azure Repos — the ADO sub-skill's Step C creates the required Branch Policy. Without it, opening a PR will not run plan.

### ARM Template gotchas (test deployments)

- **Subscription deployment schema must be `2018-05-01`.** The schema URL `https://schema.management.azure.com/schemas/2021-04-01/subscriptionDeploymentTemplate.json#` is NOT valid. ARM only supports `2014-04-01-preview, 2015-01-01, 2018-05-01, 2019-04-01, 2019-08-01` for subscription-level templates. Always use `2018-05-01/subscriptionDeploymentTemplate.json#`.
- **`utcNow()` only works in parameter defaults.** ARM rejects `utcNow()` when used directly in resource definitions (e.g., tags). Declare a parameter with `"defaultValue": "[utcNow('yyyy-MM-dd')]"` and reference `[parameters('createdDate')]` in the resource.
- **Storage account names max 24 characters.** When generating names with `uniqueString()`, always wrap with `take(..., 24)` to prevent exceeding the limit: `"[take(format('st{0}{1}{2}', params..., uniqueString(...)), 24)]"`.

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
