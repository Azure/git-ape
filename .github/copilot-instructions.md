# Azure Deployment Standards

## Naming Conventions

**⚠️ CRITICAL: Always use the `azure-naming-research` skill to lookup CAF abbreviations and Azure naming constraints before suggesting or validating resource names.**

Use consistent CAF-compliant naming patterns across all Azure resources:

**Standard Format:**
```
{resource-type-abbreviation}-{project}-{environment}-{region}[-{instance}]
```

**Resource Groups:**
- CAF abbreviation: `rg`
- Format: `rg-{project}-{environment}-{region}`
- Example: `rg-webapp-prod-eastus`
- Constraints: 1-90 chars, alphanumeric + hyphens + underscores + periods

**Function Apps:**
- CAF abbreviation: `func`
- Format: `func-{project}-{environment}-{region}`
- Example: `func-api-dev-westus2`
- Constraints: 2-60 chars, alphanumeric + hyphens, globally unique

**Storage Accounts:**
- CAF abbreviation: `st`
- Format: `st{project}{env}{random}` (lowercase, no hyphens, max 24 chars)
- Example: `stwebappdev8k3m`
- Constraints: 3-24 chars, lowercase alphanumeric only, globally unique
- Special: Use `uniqueString(resourceGroup().id)` for uniqueness

**App Service Plans:**
- CAF abbreviation: `asp`
- Format: `asp-{project}-{environment}-{region}`
- Example: `asp-webapp-prod-eastus`

**Web Apps:**
- CAF abbreviation: `app`
- Format: `app-{project}-{environment}-{region}`
- Example: `app-webapp-prod-eastus`
- Constraints: 2-60 chars, alphanumeric + hyphens, globally unique

**SQL Servers:**
- CAF abbreviation: `sql`
- Format: `sql-{project}-{environment}-{region}`
- Example: `sql-webapp-prod-eastus`
- Constraints: 1-63 chars, lowercase alphanumeric + hyphens, globally unique

**SQL Databases:**
- CAF abbreviation: `sqldb`
- Format: `sqldb-{project}-{environment}`
- Example: `sqldb-webapp-prod`

**Cosmos DB:**
- CAF abbreviation: `cosmos`
- Format: `cosmos-{project}-{environment}-{region}`
- Example: `cosmos-webapp-prod-eastus`
- Constraints: 3-44 chars, lowercase alphanumeric + hyphens, globally unique

**Application Insights:**
- CAF abbreviation: `appi`
- Format: `appi-{project}-{environment}-{region}`
- Example: `appi-webapp-prod-eastus`

**Key Vaults:**
- CAF abbreviation: `kv`
- Format: `kv-{project}-{env}-{region}`
- Example: `kv-webapp-prod-eus` (shortened region for length)
- Constraints: 3-24 chars, alphanumeric + hyphens, globally unique

**Log Analytics Workspaces:**
- CAF abbreviation: `log`
- Format: `log-{project}-{environment}-{region}`
- Example: `log-webapp-prod-eastus`
- Constraints: 4-63 chars, alphanumeric + hyphens, must start/end with alphanumeric

**Container Apps Environments:**
- CAF abbreviation: `cae`
- Format: `cae-{project}-{environment}-{region}`
- Example: `cae-api-prod-eastus`
- Constraints: 1-60 chars, alphanumeric + hyphens
- Note: Requires a Log Analytics workspace for app logs

**Container Apps:**
- CAF abbreviation: `ca`
- Format: `ca-{project}-{environment}-{region}`
- Example: `ca-api-prod-eastus`
- Constraints: 2-32 chars, lowercase alphanumeric + hyphens, must start with letter

**Naming Workflow:**

1. **Before naming ANY resource:**
   ```bash
   # Use the azure-naming-research skill
   /azure-naming-research {resource-type}
   
   # Example:
   /azure-naming-research "Azure Functions"
   
   # Returns: CAF abbreviation, length constraints, valid characters, scope
   ```

2. **Construct name using pattern:**
   ```
   {caf-abbrev}-{project}-{env}-{region}
   ```

3. **Validate against constraints:**
   - Length (min-max)
   - Character set (alphanumeric, hyphens, etc.)
   - Uniqueness scope (global, resource group, subscription)
   - Start/end character requirements

4. **For globally unique resources (Storage, Functions, SQL, Cosmos, Key Vault):**
   - Add random suffix if needed: `{name}-${random}`
   - Or use ARM's `uniqueString()` function in templates

**Reference:**
- CAF Abbreviations: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
- Naming Rules: https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules

## Default Regions

Prefer these regions for deployments unless specified otherwise:
- **Primary:** East US
- **Secondary:** West US 2
- **Europe:** West Europe

## Environment Tags

Always include these tags on all resources:
```json
{
  "Environment": "dev|staging|prod",
  "Project": "project-name",
  "ManagedBy": "git-ape-agent",
  "CreatedDate": "YYYY-MM-DD"
}
```

## ARM Template Standards

- Include `parameters` section for configurable values
- Use `outputs` section to return resource IDs and endpoints
- Apply Azure best practices via `bestpractices` service validation
- Include resource health monitoring configurations
- **Always use `/azure-rest-api-reference` to look up resource properties and API versions before writing or modifying ARM template resources** — never rely on memorized property names or schemas
- **Subscription-level templates** (`subscriptionDeploymentTemplate.json`) must use nested deployments with `"expressionEvaluationOptions": { "scope": "inner" }` — without this, `reference()` and `resourceId()` resolve at subscription scope, causing `ResourceNotFound` errors at deploy time
- All `reference()` calls inside nested templates must include explicit API versions (e.g., `reference(resourceId(...), '2024-03-01')`)
- Pass all parent-scope values (parameters, variables) as explicit parameters to nested templates — never reference parent variables directly from inner-scope templates

## Deployment Workflow

### Interactive Mode (VS Code)

1. **Requirements Gathering:** Collect all necessary parameters before generating templates
2. **Template Validation:** Always validate ARM templates before deployment
3. **User Confirmation:** Echo deployment intent and wait for explicit approval
4. **Deployment Execution:** Monitor progress and capture deployment logs
5. **Integration Testing:** Run health checks on deployed resources

### Pipeline Mode

Git-Ape supports two CI/CD providers. Choose at onboarding time via the `cicd` parameter on `/git-ape-onboarding`.

#### Pipeline Mode (GitHub Actions)

Git-Ape provides three GitHub Actions workflows under `.github/workflows/`:

##### `git-ape-plan.yml` — Validate & Preview

**Triggers:** PR opened or updated with changes to `.azure/deployments/**/template.json`

**What it does:**
1. Detects which deployment directories changed in the PR
2. Logs into Azure via OIDC
3. Validates each ARM template (`az deployment sub validate`)
4. Runs what-if analysis (`az deployment sub what-if`)
5. Reads the architecture diagram from the deployment directory
6. Posts a detailed plan as a **PR comment** (validation result + what-if + architecture)
7. Updates the comment on subsequent pushes (idempotent via HTML marker)

**PR comment includes:**
- Validation status (pass/fail with errors)
- Architecture diagram (from `architecture.md`)
- What-if analysis (resources to create/modify/delete)
- Next steps (approve + merge to deploy, or `/deploy` to deploy early)

##### `git-ape-deploy.yml` — Execute Deployment

**Triggers:**
- Push to `main` with deployment file changes (PR merge)
- `/deploy` comment on an **approved** PR

**What it does:**
1. Detects deployment directories to execute
2. Logs into Azure via OIDC
3. Validates the template one more time
4. Runs `az deployment sub create` to deploy
5. Runs integration tests (lists deployed resources, tests HTTP endpoints)
6. Commits `state.json` with deployment result back to the repo
7. Posts deployment result as a PR comment (on `/deploy` trigger)

**Requires:** GitHub environment `azure-deploy` (for environment protection rules)

**Safety:**
- `/deploy` requires PR to be approved first
- Deployments run sequentially (`max-parallel: 1`) to prevent conflicts
- In-progress deployments are never cancelled (`cancel-in-progress: false`)

##### `git-ape-destroy.yml` — Tear Down Resources

**Triggers:**
- Push to `main` with changes to `metadata.json` where status is `destroy-requested` (PR merge)
- Manual workflow dispatch with deployment ID + "destroy" confirmation (emergency fallback)

**What it does:**
1. Detects deployments where `metadata.json` status changed to `destroy-requested`
2. Reads `state.json` to find the resource group name
3. Inventories all resources in the resource group
4. Deletes the resource group (`az group delete` — synchronous, waits for completion)
5. Updates `state.json` and `metadata.json` with `destroyed` status and commits to repo

**Destroy flow:**
1. Agent or user creates a PR that sets `metadata.json` status to `destroy-requested`
2. PR is reviewed and approved (human gate for destructive action)
3. On merge to `main`, the workflow detects the status change and executes deletion

**Requires:** GitHub environment `azure-destroy` (for environment protection rules)

#### Pipeline Mode (Azure DevOps Pipelines)

Git-Ape provides four Azure DevOps pipeline files under `.azure-pipelines/`:

##### `git-ape-plan.yml` — Validate & Preview

**Triggers:** PR opened or updated against the default branch with changes to `.azure/deployments/**/template.json`.

**What it does:**
1. Detects which deployment directories changed in the PR
2. Logs into Azure via the workload identity federation service connection
3. Validates each ARM template (`az deployment sub validate`)
4. Runs what-if analysis (`az deployment sub what-if`)
5. Reads the architecture diagram from the deployment directory
6. Posts a detailed plan as a **PR thread comment** (validation result + what-if + architecture)
7. Updates the comment on subsequent pushes (idempotent via thread marker)

**PR comment includes:**
- Validation status (pass/fail with errors)
- Architecture diagram (from `architecture.md`)
- What-if analysis (resources to create/modify/delete)
- Next steps (approve the deploy environment and merge to deploy)

##### `git-ape-deploy.yml` — Execute Deployment

**Triggers:** Merge into the default branch with deployment file changes.

**What it does:**
1. Detects deployment directories to execute
2. Logs into Azure via the workload identity federation service connection
3. Validates the template one more time
4. Runs `az deployment sub create` to deploy
5. Runs integration tests (lists deployed resources, tests HTTP endpoints)
6. Commits `state.json` with deployment result back to the repo
7. Posts deployment result as a PR thread comment when run from a PR context

**Requires:** ADO environment `azure-deploy` with a pre-deployment approval check (replaces the `/deploy` PR-comment trigger from GitHub mode).

**Safety:**
- Approval gate is enforced by the environment, not by a chat command
- Deployments run sequentially via the pipeline's lock-behavior setting to prevent conflicts
- In-progress deployments are never cancelled

##### `git-ape-destroy.yml` — Tear Down Resources

**Triggers:**
- Merge into the default branch with changes to `metadata.json` where status is `destroy-requested`
- Manual pipeline run with deployment ID + "destroy" confirmation (emergency fallback)

**What it does:**
1. Detects deployments where `metadata.json` status changed to `destroy-requested`
2. Reads `state.json` to find the resource group name
3. Inventories all resources in the resource group
4. Deletes the resource group (`az group delete` — synchronous, waits for completion)
5. Updates `state.json` and `metadata.json` with `destroyed` status and commits to repo

**Requires:** ADO environment `azure-destroy` with a required-reviewer approval check.

##### `git-ape-verify.yml` — Post-Deploy Verification

**Triggers:** Manual pipeline run.

**What it does:**
1. Logs into Azure via the workload identity federation service connection
2. Re-runs integration tests against the live deployment
3. Re-validates RBAC and OIDC trust without changing any resources
4. Publishes a verification report as a pipeline artifact (no SARIF upload — that is GitHub-only)

**Requires:** Same service connection as the deploy pipeline; no environment approval needed.

### Copilot Coding Agent Flow

When the Copilot Coding Agent processes a deployment request:

```
Issue: "Deploy a Container App in Southeast Asia, project myapp"
                    │
                    ▼
    ┌───────────────────────────────┐
    │  Coding Agent (on branch)     │
    │  1. Parse requirements        │
    │  2. Generate ARM template     │
    │  3. Generate architecture.md  │
    │  4. Commit to branch          │
    │  5. Open PR                   │
    └───────────────┬───────────────┘
                    │ PR opened
                    ▼
    ┌───────────────────────────────┐
    │  git-ape-plan.yml           │
    │  1. Validate template         │
    │  2. Run what-if               │
    │  3. Post plan as PR comment   │
    └───────────────┬───────────────┘
                    │ User reviews plan
                    ▼
    ┌───────────────────────────────┐
    │  User approves PR             │
    │  - Option A: Merge → deploy   │
    │  - Option B: /deploy comment  │
    └───────────────┬───────────────┘
                    │
                    ▼
    ┌───────────────────────────────┐
    │  git-ape-deploy.yml         │
    │  1. OIDC login                │
    │  2. Deploy ARM template       │
    │  3. Integration tests         │
    │  4. Commit state.json         │
    │  5. Post result as comment    │
    └───────────────┬───────────────┘
                    │
                    ▼
    ┌───────────────────────────────┐
    │  Teardown (when needed)       │
    │  PR: set metadata.json        │
    │  status → destroy-requested   │
    │  Merge → git-ape-destroy    │
    └───────────────────────────────┘
```

### GitHub Environment Setup

Create two GitHub environments for protection rules:

**`azure-deploy`:**
- Required reviewers (optional — for prod deployments)
- Deployment branches: `main` only (for merge trigger)

**`azure-destroy`:**
- Required reviewers (recommended — destructive action)
- Deployment branches: `main` only (triggered on PR merge)

## Security Baseline

- Enable HTTPS-only for all web-facing resources
- **Always use managed identities** — never use connection strings, storage keys, or shared access keys
- For Function Apps, use `AzureWebJobsStorage__accountName` (identity-based) instead of `AzureWebJobsStorage` (key-based)
- Set `allowSharedKeyAccess: false` on storage accounts when all consumers use managed identity
- Include RBAC role assignments in ARM templates when resources access each other

### Deployment Error Recovery Rule

When a deployment fails, **never weaken security controls to fix it**. Specifically:
- Do NOT re-enable shared key access, disable firewalls, open NSGs, remove authentication, or downgrade TLS to work around errors
- Do NOT replace identity-based access with connection strings or shared keys
- Instead: verify RBAC roles are complete, check for Azure Policy conflicts, check resource dependencies and ordering, and ensure managed identities exist before dependent resources try to use them
- If the secure path genuinely cannot work, **stop and ask the user** — do not silently regress

### Security Gate Re-Run Rule

**Any modification to a template after the initial security analysis MUST trigger a full security gate re-run before deployment.** A template that passed the gate at version N is not pre-approved at version N+1.

- Use AAD-only authentication for SQL databases (`azureADOnlyAuthentication: true`)
- Use Key Vault references for secrets in app settings (`@Microsoft.KeyVault(...)`)
- Enable diagnostic logging and monitoring
- Apply least-privilege RBAC roles (use `/azure-role-selector` skill)
- Disable FTP on all App Services and Function Apps (`ftpsState: Disabled`)
- Set minimum TLS version to 1.2 on all resources

## Security Analysis Integrity

**All security reports and assessments produced by Git-Ape agents and skills MUST be factually accurate and verifiable against the actual ARM template or Azure resource configuration.**

## Compliance & Azure Policy

### Compliance Frameworks

- **Primary:** General Azure best practices
- Optionally adopt: CIS Azure Foundations v3.0, NIST SP 800-53 Rev 5, or other regulatory initiatives

### Policy Enforcement Mode

- **Default:** Audit (use `Audit`/`AuditIfNotExists` effects for initial rollout)
- **Production hardening:** Deny (use `Deny` effects for Critical-severity policies once audit baselines are clean)

### Policy Categories

Always assess and recommend policies for: identity, networking, storage, compute, monitoring, tagging.

### Policy Advisor Integration

- Use `/azure-policy-advisor` skill to assess ARM templates against compliance frameworks
- Query Microsoft Learn for current built-in policy definitions — do not hardcode policy IDs
- Output `policy-assessment.md` and `policy-recommendations.json` to deployment directory
- Policy gate is **advisory** (not blocking) — surfaces findings without halting deployment
- During onboarding, ask the user about compliance framework and enforcement mode preferences and update this section accordingly

### Rules

1. **Cite evidence**: Every "✅ Applied" finding must reference the exact ARM property path and value from the template. No exceptions.
2. **Platform defaults ≠ explicit config**: Azure automatic controls (e.g., SSE at rest on managed disks) must be labeled "🔄 Platform Default", not "✅ Applied."
3. **Honest framing**: If a resource has a public IP, it IS internet-facing. If a port is open with IP restriction, the port IS open. Never soften or misrepresent exposure.
4. **Verify before presenting**: Always re-read the ARM template and cross-check every security finding before showing it to the user. Remove or correct anything that doesn't match.
5. **When uncertain, say so**: Use "❓ Unknown" if a status cannot be verified. Never fabricate findings.

### Security Gate (Blocking)

Security analysis is a **blocking deployment gate**. Deployment CANNOT proceed until all Critical and High severity checks pass.

- **`🟢 SECURITY GATE: PASSED`** — All Critical and High checks are ✅ Applied or 🔄 Platform Default. Deployment may proceed.
- **`🔴 SECURITY GATE: BLOCKED`** — One or more Critical or High checks are ⚠️ Not applied or ❌ Misconfigured. Deployment is blocked until resolved.

When blocked, the user must either:
1. Accept proposed auto-fixes and re-run the full security analysis, or
2. Provide alternative security settings and re-run the full security analysis, or
3. Explicitly override by typing "I accept the security risk" (logged as `OVERRIDDEN` with justification)

The gate loops until PASSED or overridden — no shortcutting allowed.

## Azure Authentication

Git-Ape supports multiple execution contexts. Always use the most secure auth method available.

### Auth Method Priority

| Priority | Method | Context | How |
|----------|--------|---------|-----|
| 1 | **OIDC Federated Identity** | GitHub Actions / Azure DevOps Pipelines / Copilot Coding Agent | `azure/login@v2` (GitHub) or `AzureCLI@2` with a workload-identity-federation service connection (ADO) |
| 2 | **Managed Identity** | Azure-hosted runners / VMs | Automatic — no config needed |
| 3 | **Azure CLI session** | Local VS Code / interactive | `az login` |
| 4 | **Service Principal + secret** | Legacy CI only | Discouraged — migrate to OIDC |

### OIDC Setup for GitHub Actions

OIDC eliminates stored secrets by exchanging a short-lived GitHub token for an Azure access token at deploy time.

**One-time Azure setup:**
1. Create an Azure AD App Registration (or User-Assigned Managed Identity)
2. Add a federated credential for the GitHub repo:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Subject: `repo:{org}/{repo}:ref:refs/heads/main` (or `environment:production` for env-scoped)
   - Audience: `api://AzureADTokenExchange`
3. Grant the app the required RBAC roles on the target subscription (e.g., Contributor + User Access Administrator)

**Required GitHub secrets** (NOT actual credentials — just identifiers):
- `AZURE_CLIENT_ID` — App Registration's Application (client) ID
- `AZURE_TENANT_ID` — Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` — Target subscription ID

**Workflow snippet:**
```yaml
permissions:
  id-token: write    # Required for OIDC token request
  contents: write    # Required for committing deployment state

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - name: Deploy
        run: |
          az deployment sub create \
            --location ${{ env.LOCATION }} \
            --template-file .azure/deployments/${{ env.DEPLOYMENT_ID }}/template.json \
            --parameters @.azure/deployments/${{ env.DEPLOYMENT_ID }}/parameters.json
```

**Transitioning from Service Principal secrets to OIDC:**
1. Create the federated credential on the existing App Registration
2. Update the workflow to use `azure/login@v2` with `client-id` instead of `creds`
3. Add `permissions.id-token: write` to the workflow
4. Remove `AZURE_CREDENTIALS` secret from the repo
5. Verify with a test deployment on a dev branch

### OIDC Setup for Azure DevOps Pipelines

OIDC for Azure DevOps uses workload identity federation bound to an ADO service connection. No secrets or PATs are stored — the pipeline exchanges a short-lived ADO-issued token for an Azure access token at run time.

**One-time Azure setup:**
1. Reuse (or create) the App Registration that already backs Git-Ape's GitHub onboarding flow.
2. Add a federated credential on that App Registration:
   - Issuer: `https://vstoken.dev.azure.com/<organization-guid>`
   - Subject: `sc://<organization>/<project>/<service-connection-name>`
   - Audience: `api://AzureADTokenExchange`
3. Create the ADO service connection with workload identity federation:
   ```bash
   az devops service-endpoint azurerm create \
     --azure-rm-service-principal-id "$CLIENT_ID" \
     --azure-rm-subscription-id "$AZURE_SUBSCRIPTION_ID" \
     --azure-rm-subscription-name "$AZURE_SUBSCRIPTION_NAME" \
     --azure-rm-tenant-id "$AZURE_TENANT_ID" \
     --name "$SERVICE_CONNECTION_NAME" \
     --authentication-type workloadIdentityFederation
   ```
4. Grant the App Registration the same RBAC roles used in the GitHub flow (e.g., Contributor + User Access Administrator at subscription scope).

**Required ADO variable group entries** (NOT credentials — identifiers only):
- `AZURE_CLIENT_ID` — App Registration's Application (client) ID
- `AZURE_TENANT_ID` — Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID` — Target subscription ID

Reference the variable group from each pipeline file via `variables: - group: git-ape-azure`. The `AzureCLI@2` task picks up the federated identity from the named service connection automatically.

**Pipeline snippet:**
```yaml
variables:
  - group: git-ape-azure

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: $(SERVICE_CONNECTION_NAME)
      scriptType: bash
      scriptLocation: inlineScript
      inlineScript: |
        az deployment sub create \
          --location "$LOCATION" \
          --template-file .azure/deployments/$DEPLOYMENT_ID/template.json \
          --parameters @.azure/deployments/$DEPLOYMENT_ID/parameters.json
```

**Approval gate:** Use an ADO Environment with a pre-deployment approval check on the deploy pipeline; this replaces the `/deploy` PR-comment trigger used in GitHub mode.

### Copilot Coding Agent Considerations

When Git-Ape runs inside the Copilot Coding Agent:
- The agent operates on a branch and creates a PR — it cannot interactively confirm with the user
- Authentication must be pre-configured via OIDC in the Actions workflow
- All deployment plans should be committed as files in the PR for review
- Actual deployment should happen on merge (via a separate workflow) or via an explicit `/deploy` comment trigger
- The agent should generate the template + what-if analysis but NOT execute deployment unless the workflow is explicitly configured to do so
