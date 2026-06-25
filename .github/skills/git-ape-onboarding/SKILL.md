---
name: git-ape-onboarding
description: "Bootstrap a GitHub repository for Git-Ape CI/CD: Entra app registration, OIDC federated credentials, RBAC role assignments, GitHub environments (azure-deploy/azure-destroy), required secrets, and scaffold Actions workflow files — plus enterprise-wide distribution via a `.github-private` repo (managed-settings.json plugin standards + custom agents). USE FOR: first-time Git-Ape setup, new subscription onboarding, multi-environment (dev/staging/prod) setup, configure OIDC, federated credentials, RBAC setup, GitHub environments, scaffold workflow files, rolling Git-Ape out org/enterprise-wide. DO NOT USE FOR: deploying resources (use git-ape), drift detection alone, secret rotation."
metadata:
  argument-hint: "GitHub repo URL, subscription target(s), and onboarding mode (single or multi-environment)"
  user-invocable: true
---

# Git-Ape Onboarding

Use this skill to bootstrap a repository for Git-Ape deployments by executing the onboarding workflow directly from Copilot Chat.

This skill is the source of truth for onboarding behavior. Do not depend on a standalone repository script for setup logic.

## Onboarding Modes

This skill operates in two independent modes:

- **Repository CI/CD onboarding (default).** Configures one repository +
  subscription(s) for Git-Ape deployments: OIDC, federated credentials, RBAC,
  GitHub environments, secrets, and scaffolded workflows. This is the bulk of
  the skill (see [Command Playbook](#command-playbook)).
- **Enterprise distribution (`.github-private`).** Rolls Git-Ape out to every
  user on your org/enterprise Copilot plan by scaffolding a `.github-private`
  repo with `managed-settings.json` plugin standards (and an optional `agents/`
  directory). See [Mode: Enterprise Distribution](#mode-enterprise-distribution-github-private).

The two modes are complementary, not alternatives: enterprise distribution
installs the **tooling** for everyone, while repository onboarding wires up
**Azure access** for a specific repo. A fully onboarded user typically needs
both.

## When to Use

- First-time setup of a repository for Git-Ape
- New subscription onboarding (single environment)
- Multi-environment onboarding (dev/staging/prod across different subscriptions)
- New user handoff where OIDC, RBAC, and GitHub environments must be created
- **Enterprise-wide distribution:** rolling Git-Ape out to every user on your
  org/enterprise Copilot plan via a `.github-private` repo, so the plugin
  (agents + skills + `azure-mcp`) auto-installs on authentication — no per-user
  `gh plugin install` required

**DO NOT USE FOR:** re-deploying an already-onboarded repo (use `git-ape`), rotating or updating an existing secret or federated credential, drift detection setup alone (that is an optional sub-step covered by Step 10), or general Azure resource deployment.

## What It Configures

This skill configures:

1. Entra ID App Registration and service principal (or reuses existing)
2. OIDC federated credentials for GitHub Actions
3. RBAC role assignment(s) on subscription scope
4. GitHub environments (`azure-deploy*`, `azure-destroy`)
5. Required GitHub secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`) and the `AZURE_SUBSCRIPTION_ID` variable, plus the optional `GIT_APE_RUNNER_LABEL` variable that selects private runners
6. Scaffolded GitHub Actions workflow files (`git-ape-plan.yml`, `-deploy.yml`, `-destroy.yml`, `-verify.yml`, `-drift.{md,lock.yml}`) and deployment standards (`.github/copilot-instructions.md`) into the user's working copy
7. *(Optional)* The `COPILOT_GITHUB_TOKEN` repository secret that powers the agentic drift-detection workflow (`git-ape-drift.lock.yml`) — only when the user opts into scheduled drift detection
8. The GitHub Actions **runner type** the workflows run on — public GitHub-hosted (default), **hosted compute networking** (GitHub-managed runners with Azure private networking, requires GHEC), or self-hosted runners in your Azure subscription (ACI / ACA / AKS). On-demand IaC for private runners ships at `./templates/runners/`.

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

### Enterprise distribution (`.github-private`)

Invoke the skill in enterprise mode to scaffold the org/enterprise distribution
repo instead of onboarding a single deployment repo:

```text
/git-ape-onboarding distribute git-ape to the <org> enterprise
```

This runs the [enterprise distribution playbook](#mode-enterprise-distribution-github-private)
rather than the repository CI/CD playbook below.

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
7. Set GitHub repo or environment secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`) and the `AZURE_SUBSCRIPTION_ID` variable. (The `GIT_APE_RUNNER_LABEL` variable is set later in Step 12 only if private runners are chosen.)
8. Create GitHub environments and branch policies when permissions allow.
9. Scaffold workflow files and deployment standards into the user's working copy (see below).
10. *(Optional)* Provision the drift detector engine credential (`COPILOT_GITHUB_TOKEN`) so the agentic drift workflow can run (see below).
11. Capture compliance and Azure Policy preferences (see below).
12. Select the GitHub Actions runner type (public / hosted compute networking / self-hosted) and, if private runners are chosen, provision them and set `GIT_APE_RUNNER_LABEL` (see below).
13. Verify federated credentials, role assignments, and secrets.

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
scaffold step skips it. Step 11 (below) handles that case explicitly.

### Step 10: (Optional) Onboard the drift detector workflow

**This step is optional.** It is only needed if the user wants the scheduled
**drift-detection** workflow (`git-ape-drift.lock.yml`) to run. The `plan`,
`deploy`, `destroy`, and `verify` workflows do **not** depend on anything from
this step — skip it entirely if the user is not enabling drift detection.

Unlike the other scaffolded workflows, `git-ape-drift` is a **GitHub Agentic
Workflow** (authored with [gh-aw](https://github.github.com/gh-aw/)) that runs
on the **GitHub Copilot engine**. Its compiled `.lock.yml` opens with a hard
preflight gate — *"Validate COPILOT_GITHUB_TOKEN secret"* — that fails the run
immediately when the credential is missing. There is **no fallback**: the Azure
OIDC secrets from Step 7 cover the workflow's deterministic pre-steps, but the
agent itself needs its own engine token.

To onboard it:

1. **Confirm intent.** Ask the user whether they want scheduled drift
   detection. If not, skip this step.

2. **Provision `COPILOT_GITHUB_TOKEN`** as a **repository** secret — not an
   environment secret, because the daily `schedule` runs from `main` with no
   environment attached:
   ```bash
   gh secret set COPILOT_GITHUB_TOKEN --repo <org>/<repo>
   # paste the token when prompted — never pass it on the command line
   ```
   Token requirements:
   - A GitHub **PAT** (fine-grained or classic) belonging to an identity with
     an **active GitHub Copilot seat**.
   - The built-in `GITHUB_TOKEN` **cannot** drive the Copilot engine, so the
     token must be supplied explicitly.
   - The other gh-aw tokens (`GH_AW_GITHUB_TOKEN`,
     `GH_AW_GITHUB_MCP_SERVER_TOKEN`) are **not** required — they fall back to
     the auto-provided `GITHUB_TOKEN`.

3. **(Only if recompiling.)** The scaffolded `.lock.yml` runs as-is. The
   `gh-aw` CLI is needed **only** when the user edits `git-ape-drift.md` and
   wants to regenerate the lock file:
   ```bash
   gh extension install github/gh-aw
   gh aw compile
   ```

4. **Smoke-test** the workflow end to end:
   ```bash
   gh workflow run git-ape-drift.lock.yml --repo <org>/<repo>
   gh run list --workflow git-ape-drift.lock.yml --repo <org>/<repo> --limit 1
   ```

Never print the token value in chat output (see Safe-Execution Rules).

### Step 11: Compliance & Azure Policy Preferences

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

### Step 12: Runner Selection & Provisioning (optional)

Git-Ape workflows resolve their runner from a single variable:

```yaml
runs-on: ${{ vars.GIT_APE_RUNNER_LABEL || 'ubuntu-latest' }}
```

Unset → public GitHub-hosted `ubuntu-latest` (the default; no infrastructure).
Set to a label → private runners with that label. This is the **bootstrap model:
start public, switch to private later with one variable.**

1. **Ask the runner type:**
   ```
   What runner should the Git-Ape workflows run on?
   - Public GitHub-hosted (recommended to start — no infrastructure)
   - Hosted compute networking (GitHub-managed runners in your Azure VNet — requires GHEC)
   - Self-hosted in my Azure subscription (you manage compute, image, scaling)
   ```

2. **If public (default):** do nothing. Leave `GIT_APE_RUNNER_LABEL` unset.
   Onboarding is complete; the user can switch to private runners any time by
   repeating this step.

3. **If hosted compute networking:**
   Follow the hosted compute sub-flow (Step 12a below).

4. **If self-hosted:**
   Follow the self-hosted sub-flow (Step 12b below).

---

### Step 12a: Hosted Compute Networking (GitHub-managed, Azure private networking)

GitHub-hosted runners with Azure private networking. GitHub manages the compute
(full Ubuntu images with `az`, `gh`, `jq`, `git` pre-installed), runners execute
inside your Azure VNet for private connectivity.

**Prerequisites:** GitHub Enterprise Cloud.

**Reference:** [About networking for hosted compute products](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/about-networking-for-hosted-compute-products-in-your-enterprise)

#### a. Consolidate GitHub auth scopes first

Before starting provisioning, authenticate with **all required scopes in one
call** to avoid repeated auth prompts:

```bash
gh auth refresh -h github.com -s admin:org,admin:enterprise,manage_runners:org,read:enterprise,write:network_configurations
```

| Scope | Purpose |
|-------|---------|
| `admin:org` | Create org-level runner groups, assign repos |
| `admin:enterprise` | Enterprise-level runner groups and hosted runners |
| `manage_runners:org` | Create/manage hosted runners |
| `read:enterprise` | Query enterprise metadata (databaseId, org membership) |
| `write:network_configurations` | Create network configurations |

#### b. Ask scope: organization or enterprise

```
Where should the network configuration live?
- Enterprise level (shared across all orgs in the enterprise)
- Organization level (scoped to this org only)
```

| Scope | `businessId` value | UI location |
|-------|-------------------|-------------|
| **Enterprise** | Enterprise `databaseId` (from GraphQL) | Enterprise Settings → Hosted compute networking |
| **Organization** | Org numeric ID (REST: `.id` field) | Org Settings → Hosted compute networking |

Query the needed ID:
```bash
# Enterprise databaseId (for enterprise scope):
gh api graphql -f query='{enterprise(slug: "<slug>") { databaseId }}' --jq '.data.enterprise.databaseId'

# Org numeric ID (for org scope):
gh api orgs/<org> --jq '.id'
```

#### c. Provision Azure networking

1. Create resource group and VNet with a `/28` subnet (minimum 16 IPs):
   ```bash
   az group create --name <rg> --location <region>
   az network vnet create --name <vnet> --resource-group <rg> \
     --address-prefix 10.0.0.0/16 --subnet-name snet-runners --subnet-prefix 10.0.0.0/28
   ```

2. Delegate subnet to `GitHub.Network/networkSettings`:
   ```bash
   az network vnet subnet update --name snet-runners --vnet-name <vnet> \
     --resource-group <rg> --delegations GitHub.Network/networkSettings
   ```

3. Register `GitHub.Network` resource provider:
   ```bash
   az provider register --namespace GitHub.Network
   # Wait until Registered:
   az provider show --namespace GitHub.Network --query "registrationState" -o tsv
   ```

4. Create `GitHub.Network/networkSettings` resource:
   ```bash
   az rest --method PUT \
     --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/GitHub.Network/networkSettings/<name>?api-version=2024-04-02" \
     --body '{
       "location": "<region>",
       "properties": {
         "businessId": "<enterprise-databaseId-or-org-id>",
         "subnetId": "<full-subnet-resource-id>"
       }
     }'
   ```
   ⚠️ **`businessId` is immutable.** If wrong, you must delete and recreate.

5. Extract the `GitHubId` tag from the resource — this is the ID GitHub uses:
   ```bash
   az rest --method GET \
     --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/GitHub.Network/networkSettings/<name>?api-version=2024-04-02" \
     --query "tags.GitHubId" -o tsv
   ```

#### d. Create GitHub network configuration

Use the **`GitHubId` tag value** (NOT the Azure resource ID):

```bash
# Enterprise scope:
gh api --method POST enterprises/<slug>/network-configurations \
  -f name="<config-name>" -f compute_service="actions" \
  -f network_settings_ids[]="<GitHubId-tag-value>"

# Organization scope:
gh api --method POST orgs/<org>/settings/network-configurations \
  -f name="<config-name>" -f compute_service="actions" \
  -f network_settings_ids[]="<GitHubId-tag-value>"
```

Save the returned `id` — needed for the runner group.

#### e. Create runner group and hosted runner

```bash
# Enterprise scope:
gh api --method POST enterprises/<slug>/actions/runner-groups \
  -f name="<group-name>" -f visibility="selected" \
  -F allows_public_repositories=false \
  -f network_configuration_id="<network-config-id>"

# Assign the org to the enterprise runner group:
gh api --method PUT enterprises/<slug>/actions/runner-groups/<group-id>/organizations/<org-id>

# For enterprise groups: also assign the repo at org level (inherited group ID):
gh api orgs/<org>/actions/runner-groups --jq '.runner_groups[] | select(.name=="<group-name>") | .id'
gh api --method PUT orgs/<org>/actions/runner-groups/<inherited-id>/repositories/<repo-id>
```

```bash
# Query available images and sizes:
gh api orgs/<org>/actions/hosted-runners/images/github-owned --jq '.images[] | {id, display_name, platform}'
gh api orgs/<org>/actions/hosted-runners/machine-sizes --jq '.machine_specs[:5] | .[] | {id, cpu_cores, memory_gb}'

# Create hosted runner (image IDs are NUMERIC, sizes are like "4-core"):
echo '{"name":"<runner-name>","runner_group_id":<group-id>,"platform":"linux-x64","image":{"id":"<numeric-id>","source":"github"},"size":"4-core","maximum_runners":5}' | \
  gh api --method POST enterprises/<slug>/actions/hosted-runners --input -
```

Wait for `status: "Ready"`:
```bash
gh api enterprises/<slug>/actions/hosted-runners --jq '.runners[] | {name, status}'
```

#### f. Set variable and verify

```bash
gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --body "<runner-name>"
gh workflow run git-ape-verify.yml --repo <org>/<repo>
```

Confirm all steps pass — no custom image needed, GitHub provides everything.

---

### Step 12b: Self-Hosted Runners (ACI / ACA / AKS)

Self-hosted runners run in your Azure subscription. You manage compute, image,
scaling, and networking.

1. **Ask the platform:**
   ```
   Which Azure platform should host the runners?
   - ACI  — Azure Container Instances (simplest; a handful of runners)
   - ACA  — Azure Container Apps (event-driven, ephemeral, scale-to-zero)
   - AKS  — Azure Kubernetes Service (Actions Runner Controller; large scale)
   ```

2. **Build the custom runner image using ACR Tasks (cloud build).** The base
   `ghcr.io/actions/actions-runner:latest` (GitHub's official runner image) does
   **NOT** include `az`, `gh`, or `jq`, and ships no registration entrypoint.
   Workflows fail with `Unable to locate executable file: az` — and on ACI/ACA
   the runner never registers — without a custom image.

   Always build via **ACR Tasks** (cloud build) — never local Docker. This
   avoids Windows CRLF line-ending corruption of `entrypoint.sh` and eliminates
   the need for a local Docker install.
   ```bash
   # Create ACR (one-time) — no --admin-enabled; use managed identity for pulls
   az acr create --name <acr-name> --resource-group <rg> --location <region> --sku Basic

   # Build and push image (runs in Azure, ~3 min, no local Docker needed)
   # On Windows, add --no-logs to avoid a Unicode encoding crash in log streaming
   az acr build --registry <acr-name> --image git-ape-runner:latest \
     --file ./templates/runners/Dockerfile ./templates/runners/ --no-logs
   ```
   The `Dockerfile` at `./templates/runners/Dockerfile` extends the base runner
   with all Git-Ape prerequisites (`az`, `gh`, `jq`, `git`) and an `entrypoint.sh`
   that self-registers the runner on ACI/ACA (on AKS, ARC handles registration).
   It includes a `sed` safety net that strips CRLF line endings from
   `entrypoint.sh` at build time.

   After the build, verify the image exists:
   ```bash
   az acr repository list --name <acr-name> -o table
   ```

3. **Create a managed identity and assign `AcrPull` role** for image pulls:
   ```bash
   # Create identity
   az identity create --name id-git-ape-runner --resource-group <rg> --location <region>

   # Get IDs
   IDENTITY_ID=$(az identity show --name id-git-ape-runner --resource-group <rg> --query id -o tsv)
   PRINCIPAL_ID=$(az identity show --name id-git-ape-runner --resource-group <rg> --query principalId -o tsv)
   ACR_ID=$(az acr show --name <acr-name> --query id -o tsv)

   # Assign AcrPull role (may take 30–60s to propagate)
   az role assignment create --assignee-object-id $PRINCIPAL_ID --assignee-principal-type ServicePrincipal \
     --role AcrPull --scope $ACR_ID
   ```
   **Do NOT use ACR admin credentials** (`--admin-enabled true` + username/password).
   Managed identity is the secure, recommended approach.

4. **Collect a GitHub PAT from the user.** The ACA/ACI runner needs a
   **long-lived GitHub Personal Access Token (PAT)** — NOT a short-lived
   registration token from `POST /actions/runners/registration-token`.
   Registration tokens expire in ~1 hour, but the KEDA `github-runner` scaler
   continuously polls the Actions queue AND each ephemeral runner re-registers
   on every scale-up, so a long-lived PAT is required.

   **Ask the user to create a PAT** before deploying:
   ```
   The self-hosted runner needs a GitHub Personal Access Token (PAT) for
   continuous queue polling and runner registration.

   Please create a fine-grained PAT at:
     https://github.com/settings/tokens?type=beta

   Required permissions (scoped to the target repo):
     - Actions: Read & Write
     - Administration: Read & Write (for runner registration)

   Alternatively, a classic PAT with the `repo` scope works.

   Paste the token when prompted — it will only be passed to the deployment
   and will not be stored or displayed.
   ```

   **Do NOT generate a registration token** via the GitHub API
   (`POST repos/<org>/<repo>/actions/runners/registration-token`). These are
   short-lived (~1 hour) and will cause the runner to fail with a 401 error
   once expired. The KEDA scaler and ephemeral runner registration both need
   a token that does not expire.

   Never print the token value in chat output (see Safe-Execution Rules).

5. **Deploy the runner infrastructure** using the chosen platform template.
   Pass the custom image, ACR server, managed identity, and user-provided PAT:
   ```bash
   az deployment group create -g <rg> -f template.json \
     -p runnerImage='<acr-name>.azurecr.io/git-ape-runner:latest' \
        acrServer='<acr-name>.azurecr.io' \
        userAssignedIdentityId=$IDENTITY_ID \
        githubOwnerRepo='<org>/<repo>' \
        githubAccessToken='<user-provided-PAT>'
   ```
   - The ACA template's `registries` block automatically uses identity-based
     auth when both `acrServer` and `userAssignedIdentityId` are set.
   - The GitHub PAT is the only secret — for production, store it in Key Vault
     and reference it; for initial setup, pass it directly at deploy time.
     Never inline it in a committed `parameters.json`.
   - For private networking, set the subnet parameter (`subnetId` for ACI,
     `infrastructureSubnetId` for ACA, or a VNet node pool for AKS).
   - For AKS, use `helm install` instead of ARM.
   - **Note:** The ACA managed environment may take 1–2 minutes to fully
     provision. If deploying step-by-step (not via ARM template), wait for the
     environment's `provisioningState` to reach `Succeeded` before creating the
     job.

6. **Set `minExecutions=1`** (recommended) so at least one runner is always
   warm and visible in GitHub Settings. Without this, KEDA scale-from-zero can
   take 1–3 minutes on cold start, during which GitHub shows "No runners
   configured":
   ```bash
   az containerapp job update --name git-ape-runner --resource-group <rg> --min-executions 1
   ```
   Leave at `0` only if you prefer true scale-to-zero and can tolerate cold-start
   delays.

7. **Confirm the runner is online** in *GitHub → Settings → Actions → Runners*
   with the `git-ape-runner` label. (With `minExecutions=1`, a runner should
   appear within 30–60 seconds of deployment.)

8. **Set the variable** so workflows target it (repo-wide or per environment):
   ```bash
   gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --body "git-ape-runner"
   # per environment instead:
   gh variable set GIT_APE_RUNNER_LABEL --repo <org>/<repo> --env azure-deploy --body "git-ape-runner"
   ```
   Clean fallback to GitHub-hosted runners is `gh variable delete GIT_APE_RUNNER_LABEL`.

9. **Verify** by triggering `Git-Ape: Verify Setup` and confirming all steps
    pass on the private runner (especially "Test OIDC login" which requires `az`).

10. **Continuous drift detection** (`git-ape-drift.lock.yml`) is a compiled gh-aw
    workflow and does NOT honor `GIT_APE_RUNNER_LABEL`. To move drift onto a
    private runner, set `runs-on:` in the source `git-ape-drift.md` frontmatter
    and recompile with `gh aw compile` — never hand-edit the `.lock.yml` (it
    carries an integrity hash). The other four workflows need no recompile.

## Mode: Enterprise Distribution (`.github-private`)

Use this mode to distribute Git-Ape to **everyone on an organization's or
enterprise's Copilot plan** at once, instead of onboarding one deployment repo.
It scaffolds a special `.github-private` repository that GitHub Copilot reads to
apply **enterprise-managed plugin standards**.

> [!IMPORTANT]
> This mode configures **tooling distribution only**. It does **not** grant
> Azure access. Each user/repo that actually deploys still needs `az login`/OIDC
> and a per-repo run of the repository CI/CD playbook above.

### Why the plugin route (not `agents/` alone)

Git-Ape is a **plugin** that bundles agents **+** skills **+** the `azure-mcp`
MCP server. The `.github-private` `agents/` directory distributes **standalone
agents only** — copying Git-Ape's agents there would ship them without their
skills and MCP server, so they would load but fail. Distribute Git-Ape through
`managed-settings.json`, which auto-installs the **whole plugin**.

> [!NOTE]
> Standalone org/enterprise **skills** are "coming soon" per GitHub's docs.
> Today, Git-Ape's skills reach users because they are bundled in the plugin —
> already covered by the `managed-settings.json` route below.

### What it configures

Scaffolds, into a `.github-private` repository working copy:

1. `.github/copilot/managed-settings.json` — registers the `Azure/git-ape`
   marketplace and enables the `git-ape@git-ape` plugin for all members.
2. `README.md` — governance, admin setup steps, and caveats for maintainers.
3. `agents/.gitkeep` — placeholder for optional standalone custom agents.

### Prerequisites (enterprise mode)

- `gh` authenticated as a user with permission to **create a repo in the target
  org** (`gh auth status`).
- An **enterprise owner** to perform the AI-controls designation and ruleset
  steps (these are GitHub UI actions — see the hand-off below).
- The org that will own `.github-private` is part of the enterprise.

### Enterprise distribution playbook

The agent can automate steps 1–4 via CLI; steps 5–6 are **UI-only** and must be
handed off to an enterprise owner.

1. **Confirm the target org/enterprise and ownership**, then echo the plan and
   require explicit confirmation before creating anything.

2. **Create (or reuse) the `.github-private` repo** in the target org.
   `--internal` gives every enterprise member read access; use `--private` to
   grant access manually:
   ```bash
   gh repo create <org>/.github-private \
     --internal \
     --description "Copilot enterprise configuration (Git-Ape standards)"
   gh repo clone <org>/.github-private /tmp/github-private
   ```

3. **Scaffold the canonical files** into the cloned repo root. Two parity
   implementations ship — pick the one matching the user's shell, and pass the
   cloned repo path as the target:
   ```bash
   # macOS / Linux / WSL
   .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.sh /tmp/github-private
   ```
   ```powershell
   # Windows (PowerShell 7+)
   pwsh .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.ps1 C:\path\to\github-private
   ```
   Both scripts produce byte-identical output and follow the same
   skip-with-notice / no-git rules as the repository scaffolder (Step 9 above).
   The onboarding-template-check workflow enforces parity on every PR.

4. **Review and publish.** Edit `managed-settings.json` if you want to also
   enable the optional `ape-context@git-ape` companion plugin, then review the
   `README.md` placeholders. The scaffolder leaves everything **unstaged** — let
   the user (or a reviewed PR) commit and push to the default branch:
   ```bash
   cd /tmp/github-private
   jq empty .github/copilot/managed-settings.json   # validate before publishing
   git add .github/copilot/managed-settings.json README.md agents/.gitkeep
   git commit -m "Add Git-Ape enterprise Copilot standards"
   git push
   ```

5. **Hand off the enterprise designation (UI-only).** Instruct an enterprise
   owner to open **Enterprise → AI controls → Custom agents → _Select
   organization_** and choose the org that owns `.github-private`. This same
   designation points the enterprise at the repo's `managed-settings.json`.
   There is no stable CLI/API for this during public preview — the agent must
   hand off with the link, not attempt to automate it.

6. **(Recommended) Protect the files (UI-only).** On the same AI-controls page,
   under _"Protect agent files using rulesets"_, create a ruleset so only
   enterprise owners can merge changes.

### Verification (enterprise mode)

```bash
# Confirm the standards landed on the default branch of the config repo
gh api repos/<org>/.github-private/contents/.github/copilot/managed-settings.json --jq '.path'

# Validate the published JSON is well-formed
gh api repos/<org>/.github-private/contents/.github/copilot/managed-settings.json \
  --jq '.content' | base64 --decode | jq empty && echo "✓ managed-settings.json is valid JSON"
```

Then, on a **supported client** (Copilot CLI, or VS Code 1.122+), a member of
the designated org re-authenticates and confirms the `git-ape` plugin
auto-installed. Users licensed by multiple billing entities must select this
enterprise under _"Usage billed to"_ in their personal Copilot settings.

### After distribution: still onboard repos for Azure

Distribution installs the Git-Ape tooling everywhere, but deployments still need
Azure identity. For each repository that will deploy, run the **repository
CI/CD** playbook above (`/git-ape-onboarding onboard <repo> ...`) to wire up
OIDC, RBAC, environments, and workflows.

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
8. **Idempotency on re-run:** If the skill is re-invoked after a partial failure, re-run from the last failing step — not from scratch. The Entra app, federated credentials, role assignments, and GitHub environments created before the failure are safe to reuse; do not create duplicates. Surface each already-provisioned resource as `⊝ Already exists` rather than re-creating it.
9. **Enterprise mode:** confirm the target org belongs to the enterprise and the
   operator can create `.github-private` before running `gh repo create`. Never
   force-push or overwrite an existing `.github-private` default branch.
10. **Enterprise mode:** never claim to have automated the **AI-controls
   designation** or **ruleset** — these are UI-only, enterprise-owner actions.
   Hand them off with the exact navigation path and stop.

## Suggested Agent Flow

### Repository CI/CD onboarding

**First-turn rule:** the very first response to any onboarding request must be a **gated handoff** — surface prereq results and collect required inputs. It must NOT be a walkthrough, a full set of CLI commands, or a completion report. The agent must not narrate or execute onboarding steps until: (a) prereq check confirms ✅ READY, and (b) all five required inputs from step 2 are in hand.

1. **Run `/prereq-check`** to validate tools and auth. Surface the full results table — tool versions, Azure CLI auth status, GitHub CLI auth status, and a ✅/❌ per check. If CLI commands cannot execute in the current environment, present the required checklist items and ask the user to confirm each one passes manually (`az` ≥ 2.50 installed and authenticated, `gh` ≥ 2.0 installed and authenticated, `jq` ≥ 1.6, `git` installed). **Never advance to step 2 until prereq results are confirmed — this is a hard gate.**
2. **Collect the required inputs.** Ask for — and wait for answers to — at minimum: (1) target GitHub repository URL, (2) Azure subscription ID (or one per environment for multi-env), (3) RBAC role to grant (`Contributor` or `Owner`), (4) onboarding mode (`single` or `multi-environment`), (5) default branch (confirm `main` or ask if non-standard). Do not proceed to step 3 without all five.
3. Validate current Azure/GitHub auth context (subscription, tenant, GitHub org).
4. Ask for final confirmation.
5. Execute the required Azure CLI and GitHub CLI commands directly from this playbook.
6. Scaffold workflow files and `copilot-instructions.md` via `./scripts/scaffold-repo.sh` on macOS/Linux/WSL, or `pwsh ./scripts/scaffold-repo.ps1` on Windows (Step 9 in playbook). Report which files were created vs skipped.
7. *(Optional)* Offer to onboard the drift detector workflow by provisioning `COPILOT_GITHUB_TOKEN` (Step 10 in playbook). Skip if the user does not want scheduled drift detection.
8. Ask compliance framework and enforcement mode preferences (Step 11 in playbook).
9. Update `copilot-instructions.md` with compliance preferences — or, if the file was skipped by the scaffold step, surface the preferences in chat for manual integration.
10. Ask the runner type (and platform/scope if private), and — if private runners are chosen — provision the full stack. For **hosted compute networking**: consolidate gh auth scopes → ask org vs enterprise scope → provision Azure VNet + subnet → create GitHub.Network/networkSettings → create network config + runner group + hosted runner → assign repo → set `GIT_APE_RUNNER_LABEL` (Step 12a). For **self-hosted**: ask the user for a GitHub PAT (never generate a registration token) → ACR (no admin) + cloud build via ACR Tasks (`--no-logs` on Windows) + managed identity with `AcrPull` role + ACA/ACI deployment with identity-based registry auth using user-provided PAT + `minExecutions=1` + `GIT_APE_RUNNER_LABEL` (Step 12b).
11. **Verify** by triggering `Git-Ape: Verify Setup` and confirming ALL steps pass on the private runner.
12. Summarize outcome (including scaffolded file counts and the chosen runner type) and suggest verification commands.

### Enterprise distribution

1. Confirm the target org/enterprise, ownership, and that `gh` is authenticated with repo-create permission.
2. Echo the plan (create `<org>/.github-private`, scaffold standards) and ask for final confirmation.
3. Create/clone `.github-private` and run `scaffold-enterprise.sh` / `scaffold-enterprise.ps1` against the clone (Steps 2–3 of the enterprise playbook).
4. Review `managed-settings.json` (optionally enable `ape-context@git-ape`), validate the JSON, and have the user commit & push (Step 4).
5. Hand off the UI-only steps to an enterprise owner: AI-controls designation + ruleset (Steps 5–6).
6. Provide the verification commands and remind the user that each deploying repo still needs the repository CI/CD onboarding for Azure access.

## Known Gotchas

### Self-hosted: registration tokens don't work for KEDA-based runners

**Never use `POST repos/<org>/<repo>/actions/runners/registration-token`** to
generate the `githubAccessToken` for ACA/ACI runners. Registration tokens are
short-lived (~1 hour) and expire silently. Once expired:
- The KEDA `github-runner` scaler can no longer poll the Actions queue
- Each ephemeral runner fails to register on scale-up with a **401 Unauthorized**
- Runners appear as `offline` in GitHub Settings

The `githubAccessToken` parameter requires a **long-lived GitHub PAT** because:
1. KEDA continuously polls the GitHub API every 30 seconds to detect queued jobs
2. Each ephemeral runner re-registers itself on every scale-up event
3. Both operations need a token that outlives any single job

**Fix:** Always **ask the user** to create a fine-grained PAT
(`https://github.com/settings/tokens?type=beta`) with **Actions (Read & Write)**
and **Administration (Read & Write)** permissions scoped to the target repo. A
classic PAT with the `repo` scope also works. Never generate a registration
token programmatically — it will always fail after ~1 hour.

### Hosted compute: `network_settings_ids` expects the GitHubId tag, not the Azure resource ID

When creating a GitHub network configuration, the `network_settings_ids` field
expects the **`GitHubId` tag value** (a SHA-256 hash assigned by GitHub to the
Azure `GitHub.Network/networkSettings` resource), NOT the Azure resource ID path.

```bash
# ❌ WRONG — Azure resource ID
-f network_settings_ids[]="/subscriptions/.../providers/GitHub.Network/networkSettings/my-resource"

# ✅ CORRECT — GitHubId tag value from the Azure resource
-f network_settings_ids[]="FA1AD85973374477AF8C49119ADEA731EFD4B9BD6B7764A8FCD6B036CBA796F3"
```

Extract the GitHubId after creating the Azure resource:
```bash
az rest --method GET \
  --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/GitHub.Network/networkSettings/<name>?api-version=2024-04-02" \
  --query "tags.GitHubId" -o tsv
```

### Hosted compute: `businessId` is immutable and scope-specific

The `businessId` on `GitHub.Network/networkSettings` determines whether the
resource works at enterprise or organization scope:
- **Enterprise scope:** use the enterprise `databaseId` (query via GraphQL)
- **Organization scope:** use the org's numeric ID (query via REST `.id` field)

If wrong, the GitHub API returns `"The business ID is invalid or does not match"`.
The property is **immutable** — you cannot update it; you must delete and recreate.

### Hosted compute: repeated auth prompts from missing scopes

The hosted compute provisioning flow requires **5 distinct GitHub token scopes**
(`admin:org`, `admin:enterprise`, `manage_runners:org`, `read:enterprise`,
`write:network_configurations`). If not collected upfront, each missing scope
triggers a separate `gh auth refresh` device-code flow.

**Fix:** Always consolidate auth at the start of Step 12a:
```bash
gh auth refresh -h github.com -s admin:org,admin:enterprise,manage_runners:org,read:enterprise,write:network_configurations
```

### Hosted compute: image and size IDs are GitHub-specific

The hosted runners API uses **numeric image IDs** (e.g., `"2295"` = Ubuntu 24.04)
and **GitHub-specific size IDs** (e.g., `"4-core"`, `"8-core"`), not Azure VM SKU
names or Ubuntu version strings.

Always query available options first:
```bash
gh api orgs/<org>/actions/hosted-runners/images/github-owned --jq '.images[] | {id, display_name}'
gh api orgs/<org>/actions/hosted-runners/machine-sizes --jq '.machine_specs[:10] | .[] | {id, cpu_cores, memory_gb}'
```

### Default runner image lacks required tools (self-hosted only)

The base image `ghcr.io/actions/actions-runner:latest` (GitHub's official runner)
is a **minimal** self-hosted runner — it does NOT include `az`, `gh`, or `jq`, and
ships no registration entrypoint. If you deploy without the custom image, the
runner never registers on ACI/ACA and workflows fail with:

```
Error: Unable to locate executable file: az
```

**Fix:** Always build and use the custom image from `./templates/runners/Dockerfile`.
The onboarding flow must:
1. Create an ACR (`az acr create` — no `--admin-enabled`)
2. Build the image via ACR Tasks (`az acr build --no-logs` on Windows)
3. Create a managed identity with `AcrPull` role on the ACR
4. Deploy the template with `acrServer`, `userAssignedIdentityId`, and `runnerImage`

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

### Windows CRLF corrupts `entrypoint.sh` (self-hosted only)

When the `Dockerfile` build context is uploaded from a Windows checkout (where
`git autocrlf` converts LF to CRLF), `entrypoint.sh` gets `\r\n` line endings.
Linux interprets the shebang as `#!/usr/bin/env bash\r`, failing with:

```
'bash\r': No such file or directory
```

The runner container starts but never registers, and all executions fail
immediately.

**Fix (belt-and-suspenders):**
1. The `Dockerfile` includes a `sed -i 's/\r$//'` line after `COPY entrypoint.sh`
   that strips CRLF at build time — this is always safe and is a no-op on clean
   LF files.
2. Prefer **ACR Tasks** (cloud build) over local `docker build` — ACR Tasks run
   in Linux and handle the context correctly.
3. If building locally on Windows, ensure `.gitattributes` marks `*.sh` as
   `text eol=lf`, or run `dos2unix entrypoint.sh` before building.

### `az acr build` crashes on Windows (Unicode encoding)

On Windows, `az acr build` may crash while streaming build logs with:

```
UnicodeEncodeError: 'charmap' codec can't encode character '\u2192'
```

This is a known Azure CLI bug — the `colorama` library on Windows can't encode
Unicode characters (like `→`) in `apt-get` output. The build itself may or may
not have completed in Azure before the crash.

**Fix:** Always use `--no-logs` when running `az acr build` on Windows:
```bash
az acr build --registry <acr-name> --image git-ape-runner:latest \
  --file ... ... --no-logs
```
The build runs in Azure regardless; `--no-logs` just skips the local log
streaming. Verify success with `az acr repository list --name <acr-name>`.

### ACA managed environment provisioning delay

The `Microsoft.App/managedEnvironments` resource can take 1–2 minutes to
provision. If you create the ACA job immediately after the environment, the
deployment may fail with `ManagedEnvironmentNotProvisioned`.

**Fix:** When deploying via ARM template (`az deployment group create`), the
`dependsOn` in the template handles ordering automatically. When deploying
step-by-step (e.g., `az containerapp env create` followed by
`az containerapp job create`), poll the environment status first:
```bash
az containerapp env show --name <env-name> --resource-group <rg> \
  --query "properties.provisioningState" -o tsv
# Wait until "Succeeded" before creating the job
```

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

# (Optional, drift detector) Confirm the Copilot engine credential is set
gh secret list --repo <ORG>/<REPO> | grep -q '^COPILOT_GITHUB_TOKEN' \
  && echo "✅ COPILOT_GITHUB_TOKEN set" \
  || echo "⚠️ COPILOT_GITHUB_TOKEN missing — drift workflow will fail its preflight"
```
