<!-- markdownlint-disable-file -->
# Implementation Details: Add Azure DevOps as a CI/CD Option in Onboarding Agent

## Context Reference

Sources: `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md`; user conversation 2026-04-27.

## Implementation Phase 1: Onboarding Agent + Skill Provider Branching

<!-- parallelizable: true -->

### Step 1.1: Add CI/CD provider selection to onboarding agent

Insert a "Step 1.5: Select CI/CD platform" between current Step 1 (confirm repo URL) and Step 2 (single vs multi-environment) in the agent workflow. Use `vscode_askQuestions` with three options: GitHub Actions (default), Azure DevOps, Both.

When ADO or Both is selected, also collect:
* Azure DevOps organization URL (e.g. `https://dev.azure.com/contoso`).
* Azure DevOps project name.
* Source repo location: Azure Repos OR GitHub (asked only if Both not chosen, since Both implies GitHub).
* Service connection name prefix (default `git-ape-azure`).

Update the Validation block to run `az devops configure -l` and confirm `az extension show -n azure-devops` returns a version when ADO mode is active.

Files:
* `.github/agents/git-ape-onboarding.agent.md` - Add Step 1.5; branch validation block; reference ADO acknowledgement variant if any.

Discrepancy references:
* Addresses DR-01 (no current ADO selection mechanism).

Success criteria:
* Agent prompts the user once with a single multi-choice selector for CI provider.
* When ADO or Both selected, agent collects org/project/repo-backend before proceeding.
* `vscode_askQuestions` continues to be the only interaction primitive — no inline `read` prompts.

Context references:
* `.github/agents/git-ape-onboarding.agent.md` (Lines 27-53) - Existing 12-step workflow.
* `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` § "Selected approach — Scenario A".

Dependencies:
* None — agent file edit only.

### Step 1.2: Branch the skill playbook by provider

Modify the "Command Playbook" section of `git-ape-onboarding/SKILL.md` so each numbered step indicates whether it is shared, GitHub-only, or ADO-only.

Provider-shared steps (unchanged): 1 (prereq), 3 (Entra app + SP), 6 (RBAC), 9 (compliance Q&A), 10 (acknowledgements), 12 (verification).

Provider-conditional steps:
* Step 2 (resolve repo metadata) — GitHub: existing `gh repo view` + `gh api orgs/<org>/actions/oidc/customization/sub`. ADO: `az devops project show -p "$ADO_PROJECT" --org "$ADO_ORG_URL"` and resolve org GUID via `https://dev.azure.com/<org>/_apis/connectionData?api-version=7.1`.
* Step 4 (build OIDC subject) — GitHub: existing `OIDC_PREFIX` logic. ADO: subject is `sc://<org>/<project>/<connection>`; build deterministically from collected inputs.
* Step 5 (create federated creds) — GitHub: per-branch / per-env subjects. ADO: one federated cred per service connection; for multi-env, create one service connection per env.
* Step 7 (set secrets) — GitHub: `gh secret set AZURE_CLIENT_ID --env azure-deploy ...`. ADO: `az pipelines variable-group create --name git-ape-azure-secrets --variables AZURE_CLIENT_ID=<id> AZURE_TENANT_ID=<id> AZURE_SUBSCRIPTION_ID=<id>` then mark each as secret with `az pipelines variable-group variable update --secret true`.
* Step 8 (create environments) — GitHub: `gh api repos/.../environments`. ADO: `az devops invoke --area distributedtask --resource environments --http-method POST` (no first-class CLI) plus add approval checks via the same area's `checks/configurations` resource.
* Step 11 (activate workflows) — GitHub: existing `.exampleyml` → `.yml` rename in `.github/workflows/`. ADO: `.examplepipeline.yml` → `.yml` rename in `.azure-pipelines/`, plus `az pipelines create` to register each pipeline against the repo. Both: run both branches sequentially.
* Step 11c (ADO only — grant build-identity Contribute on repo): runs `az devops security permission update` against namespace `Git Repositories` for the project's build identity (`Project Collection Build Service (<org>)`) so the deploy and destroy pipelines can push `state.json`/`metadata.json` via `$(System.AccessToken)` without a PAT. Skipped for Azure-Repos-on-different-project setups (in which case onboarding falls back to documenting the manual portal grant). Required to keep workload-identity-only posture (addresses DR-06).

Add a new "Execution Modes" subsection documenting the parameter:
```text
/git-ape-onboarding cicd ado on https://dev.azure.com/contoso project=infra subscription=...
/git-ape-onboarding cicd both on https://github.com/contoso/repo subscription=...
```

Files:
* `.github/skills/git-ape-onboarding/SKILL.md` - Branch playbook steps 2, 4, 5, 7, 8, 11; add Execution Modes parameter; add ADO Known Gotchas (no `issue_comment` trigger; subject is per-connection; SARIF unavailable).

Discrepancy references:
* Addresses DR-02 (no ADO command playbook today).
* Aligns with DD-01 (deviation from research's per-env-app suggestion — see Planning Log).

Success criteria:
* Playbook is unambiguous about which steps run for which provider.
* No GitHub-only commands appear unconditionally.
* ADO branch documents service-connection-per-env model.

Context references:
* `.github/skills/git-ape-onboarding/SKILL.md` (Lines 67-117) - Current Command Playbook.
* `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` § "GitHub vs Azure DevOps Primitive Mapping".

Dependencies:
* Step 1.1 design decisions (provider selection mechanism) — but file-level changes can proceed in parallel.

### Step 1.3: Add `az devops` extension and login check to prereq-check skill

Extend `prereq-check/SKILL.md` to conditionally validate the ADO toolchain when invoked from `/git-ape-onboarding` with `cicd ado|both`.

Validation commands to add:
* `az extension show --name azure-devops --query version -o tsv` — installs via `az extension add --name azure-devops` if missing.
* `az devops configure --list | grep organization` — warns if no default org configured.
* Optional: `az devops user show --org <org> --query "user.descriptor"` — verifies credentials reach the org.

Files:
* `.github/skills/prereq-check/SKILL.md` - Add ADO conditional checks under a new "If ADO selected" subsection.

Success criteria:
* Skill reports ✅ READY only when ADO toolchain is also satisfied (when ADO mode active).
* Install commands shown for both macOS, Linux, and Windows when missing.

Context references:
* `.github/skills/prereq-check/SKILL.md` - Existing tool checks.

Dependencies:
* None — independent file edit.

## Implementation Phase 2: ADO Pipeline Example Files

<!-- parallelizable: true -->

Each file lives at `.azure-pipelines/<name>.examplepipeline.yml` and is renamed to `<name>.yml` during onboarding Step 11. All four files use:
* `trigger:` and `pr:` with `paths: include: [.azure/deployments/**/template.json, .azure/deployments/**/parameters.json]`.
* `variables: - group: git-ape-azure-secrets` for `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`.
* `AzureCLI@2` task with `azureSubscription: 'git-ape-azure'` for OIDC login.
* Pipeline artifacts via `PublishPipelineArtifact@1` / `DownloadPipelineArtifact@2`.

**Matrix-over-deployments translation (addresses DR-07):** the GitHub workflows compute a JSON list of changed deployment IDs and feed it into `strategy.matrix`. ADO equivalent uses `strategy: matrix:` from a runtime variable produced by an earlier step (`echo "##vso[task.setVariable variable=DEPLOYMENT_IDS;isOutput=true]$IDS_JSON"`) consumed by a downstream job via `dependencies.<job>.outputs['<step>.DEPLOYMENT_IDS']`. Closer to GitHub semantics than `each` template loops and keeps the pipeline shape comparable for reviewers.

### Step 2.1: Create `.azure-pipelines/git-ape-plan.examplepipeline.yml`

Mirrors `git-ape-plan.exampleyml`:
* PR trigger on path filter.
* Detects changed deployments via `git diff` against `$(System.PullRequest.TargetBranch)`.
* Runs `az deployment sub validate` and `az deployment sub what-if`.
* Runs the same security scans currently invoked by the GitHub workflow (Checkov, ARM-TTK, PSRule, Microsoft Defender for DevOps template analyzer).
* Posts plan as PR thread:
  * Azure Repos backend: `POST $(System.CollectionUri)$(System.TeamProject)/_apis/git/repositories/$(Build.Repository.ID)/pullRequests/$(System.PullRequest.PullRequestId)/threads?api-version=7.1` using `$(System.AccessToken)`.
  * GitHub backend: `POST https://api.github.com/repos/<owner>/<repo>/issues/<pr>/comments` using GitHub service connection token.

Files:
* `.azure-pipelines/git-ape-plan.examplepipeline.yml` - New file.

Discrepancy references:
* Addresses DR-03 (no ADO plan pipeline today).
* Notes DD-02 (SARIF upload omitted; results published as artifact only — see Planning Log).

Success criteria:
* Pipeline syntactically validates against `az pipelines validate` (or fails with a clearly documented schema error).
* Required tasks are pinned to known-good versions.
* PR thread payload renders the plan + what-if + architecture diagram identically to the GitHub PR comment.

Context references:
* `.github/workflows/git-ape-plan.exampleyml` (Lines 1-600) - Reference implementation.
* `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` § "Configuration Examples".

Dependencies:
* None — new file.

### Step 2.2: Create `.azure-pipelines/git-ape-deploy.examplepipeline.yml`

Mirrors `git-ape-deploy.exampleyml`, with the following deviations:
* No `issue_comment` / `/deploy` trigger — replaced by an `environment:` block on the deploy stage. The environment (`azure-deploy`) carries a manual approval check that gates execution.
* Trigger: `trigger:` on `main` with path filter only. Removes the GitHub-only "comment trigger" path.
* Stages:
  * `validate` — re-runs `az deployment sub validate`.
  * `deploy` — wrapped in `environment: azure-deploy`; runs `az deployment sub create` once approval is granted.
  * `integration_test` — runs the same integration scripts.
  * `commit_state` — uses `$(System.AccessToken)` to commit `state.json` back. Build identity must have "Contribute" permission on the target repo.

Files:
* `.azure-pipelines/git-ape-deploy.examplepipeline.yml` - New file.

Discrepancy references:
* Addresses DR-04 (no ADO deploy pipeline today).
* DD-03 (replacing `/deploy` comment with environment approval — explicit divergence from GitHub flow).

Success criteria:
* Pipeline validates and runs through the approval gate on a sandbox env.
* `state.json` commit succeeds via `System.AccessToken` without any PAT.

Context references:
* `.github/workflows/git-ape-deploy.exampleyml` - Reference implementation.

Dependencies:
* `azure-deploy` ADO Environment must exist (created during onboarding Step 8).

### Step 2.3: Create `.azure-pipelines/git-ape-destroy.examplepipeline.yml`

Mirrors `git-ape-destroy.exampleyml`:
* `trigger:` on `main` with path filter `metadata.json`.
* In-pipeline detection step reads `metadata.json` and proceeds only if `status == "destroy-requested"`.
* `environment: azure-destroy` block with manual approval (recommended).
* Manual run dispatch fallback exposed via `parameters:` (deployment ID + "destroy" confirmation token).
* Runs `az group delete --yes --no-wait=false` then commits updated `state.json` and `metadata.json`.

Files:
* `.azure-pipelines/git-ape-destroy.examplepipeline.yml` - New file.

Discrepancy references:
* Addresses DR-05 (no ADO destroy pipeline today).

Success criteria:
* Status-change detection logic equivalent to GitHub workflow.
* Approval gate enforced before deletion.
* Post-destroy commit succeeds via `System.AccessToken`.

Context references:
* `.github/workflows/git-ape-destroy.exampleyml` - Reference implementation.
* `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` § "Potential Next Research" item 4 — confirm trigger path.

Dependencies:
* `azure-destroy` ADO Environment with required reviewer.

### Step 2.4: Create `.azure-pipelines/git-ape-verify.examplepipeline.yml`

Mirrors `git-ape-verify.exampleyml`. Triggered after deploy completes (using `resources: pipelines:` chaining or a separate path filter on `state.json` updates). Runs the post-deploy verification scripts unchanged.

Files:
* `.azure-pipelines/git-ape-verify.examplepipeline.yml` - New file.

Success criteria:
* Verify pipeline runs immediately after a successful deploy.
* Failures surface as ADO build status on the merge commit.

Context references:
* `.github/workflows/git-ape-verify.exampleyml` - Reference implementation.

Dependencies:
* `git-ape-deploy` pipeline must publish a pipeline resource for chaining.

## Implementation Phase 3: Documentation Updates

<!-- parallelizable: true -->

### Step 3.1: Restructure `copilot-instructions.md` Pipeline Mode section to be provider-agnostic

Current structure (line ~163): single section "Pipeline Mode (GitHub Actions)" listing three workflows. Replace with:

```text
### Pipeline Mode

Git-Ape supports two CI/CD providers. Choose at onboarding time.

#### Pipeline Mode (GitHub Actions)

(existing content moved here verbatim, with workflow-name table unchanged)

#### Pipeline Mode (Azure DevOps Pipelines)

Git-Ape provides four pipeline files under `.azure-pipelines/`:

##### git-ape-plan.yml — Validate & Preview
##### git-ape-deploy.yml — Execute Deployment
##### git-ape-destroy.yml — Tear Down Resources
##### git-ape-verify.yml — Post-Deploy Verification
```

Each ADO subsection mirrors the GitHub one but documents:
* Trigger differences (no `issue_comment`).
* Approval gate via Environment instead of PR review for `/deploy`.
* Variable group + service connection names.

Files:
* `.github/copilot-instructions.md` - Pipeline Mode restructure (lines ~163-270).

Success criteria:
* No reader infers "Git-Ape only supports GitHub" from this file.
* Both provider sections reference `.github/workflows/` and `.azure-pipelines/` paths respectively.

Context references:
* `.github/copilot-instructions.md` (Lines 163-270) - Existing Pipeline Mode section.

Dependencies:
* None.

### Step 3.2: Add "OIDC Setup for Azure DevOps" auth section to `copilot-instructions.md`

Add a sibling subsection under § Azure Authentication after the existing "OIDC Setup for GitHub Actions" (line ~381):

```text
### OIDC Setup for Azure DevOps Pipelines

OIDC for ADO uses workload identity federation bound to a service connection.

One-time Azure setup:
1. Reuse (or create) the App Registration from GitHub onboarding.
2. Add a federated credential:
   - Issuer: https://vstoken.dev.azure.com/<org-guid>
   - Subject: sc://<org>/<project>/<service-connection-name>
   - Audience: api://AzureADTokenExchange
3. Create the ADO service connection with --authentication-type workloadIdentityFederation.
4. Grant the App Registration the required RBAC roles (same as GitHub flow).

Required ADO variable group entries (NOT credentials — identifiers only):
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID
```

Update the Auth Method Priority table to add ADO as a row equal to GitHub Actions ("OIDC Federated Identity — GitHub Actions / Azure DevOps Pipelines / Copilot Coding Agent").

Files:
* `.github/copilot-instructions.md` - Add OIDC ADO subsection; update Priority table.

Success criteria:
* ADO setup steps mirror GitHub steps in structure (same numbered ordering).
* Priority table treats both providers as Tier 1.

Context references:
* `.github/copilot-instructions.md` (Lines 376-430) - Existing Azure Authentication section.

Dependencies:
* None.

### Step 3.3: Update `docs/ONBOARDING.md` with ADO branch

Add a "Choosing your CI/CD provider" section at the top, then provider-specific subsections covering:
* Prerequisites unique to each.
* Onboarding command examples.
* Troubleshooting (e.g. `AADSTS700213` for GitHub remains; for ADO add "Service connection authorization failed" diagnosis).

Files:
* `docs/ONBOARDING.md` - Add ADO branch.

Success criteria:
* Doc references both providers from the table of contents.
* Each provider has working command examples.

Context references:
* `docs/ONBOARDING.md` - Existing GitHub-only onboarding instructions.

Dependencies:
* None.

### Step 3.4: Update website docs (onboarding + agent + skill pages)

Mirror the README structure into:
* `website/docs/getting-started/onboarding.md` — provider-agnostic intro + two subsections.
* `website/docs/agents/git-ape-onboarding.md` — describe the new `cicd` parameter and Step 1.5.
* `website/docs/skills/git-ape-onboarding.md` — link to the playbook's branched steps.

Files:
* `website/docs/getting-started/onboarding.md` - Add ADO content.
* `website/docs/agents/git-ape-onboarding.md` - Document `cicd` parameter.
* `website/docs/skills/git-ape-onboarding.md` - Reflect branched playbook.

Success criteria:
* Docusaurus build passes with no broken links.
* Sidebar navigation surfaces both providers.

Context references:
* Existing GitHub-only versions of each page.

Dependencies:
* None.

### Step 3.5: Update `.github/agents/git-ape.agent.md` to reference both pipeline modes

The orchestrator agent currently describes the deploy lifecycle as a GitHub Actions flow. Update it to:
* Replace any phrase locking the description to GitHub Actions with provider-agnostic wording.
* Add a one-paragraph note that the actual CI provider is selected at onboarding time and either `.github/workflows/git-ape-*.yml` or `.azure-pipelines/git-ape-*.yml` (or both) will be active.
* Keep all downstream agent references (e.g. `azure-resource-deployer`) unchanged — they remain provider-agnostic.

Files:
* `.github/agents/git-ape.agent.md` - Provider-agnostic rewording in the orchestration-flow section.

Discrepancy references:
* Addresses DR-05.

Success criteria:
* No reader of `git-ape.agent.md` infers GitHub-only after the change.
* No new technical detail leaks into the orchestrator agent (it stays a high-level overview).

Context references:
* `.github/agents/git-ape.agent.md` - Existing orchestration description.

Dependencies:
* None.

## Implementation Phase 4: Validation

<!-- parallelizable: false -->

### Step 4.1: Run full project validation

Execute:
* Markdown lint (repo's `mega-linter` configuration).
* Docusaurus build: `cd website && npm run build`.
* `yamllint` on `.azure-pipelines/*.examplepipeline.yml`.

### Step 4.2: Fix minor validation issues

Iterate on lint warnings, broken links, and YAML schema warnings.

### Step 4.3: Manual end-to-end dry-run

* Onboard a sandbox repo + sandbox ADO project + sandbox subscription.
* Confirm:
  * `az devops service-endpoint azurerm create --authentication-type workloadIdentityFederation` succeeds.
  * Federated credential is created with the correct `sc://<org>/<project>/<conn>` subject.
  * Variable group is created and visible in `az pipelines variable-group list`.
  * Plan pipeline runs on a test PR and posts the comment.
  * Deploy pipeline waits at the environment approval check, executes after approval, and commits `state.json`.
  * Destroy pipeline reacts to a `destroy-requested` PR merge.

### Step 4.4: Report blocking issues

Document any issues that exceed minor fixes, including:
* If `az devops invoke` against the Environments REST API requires PAT in the user's tenant — report and propose follow-up.
* If `metadata.json` path filter does not reliably trigger destroy pipeline — propose follow-up planning.
* SARIF / Defender for DevOps integration — likely follow-up.

Provide user with next steps and recommend additional planning rather than inline fixes.

## Dependencies

* `az` CLI ≥ 2.50 with `azure-devops` extension.
* `gh` CLI ≥ 2.0.
* Azure DevOps Project Collection Administrator privileges.
* Sandbox ADO org + project for end-to-end validation.

## Success Criteria

* Onboarding accepts `cicd github|ado|both` parameter and produces a fully working pipeline set in the chosen provider(s).
* Both provider branches preserve the workload-identity-federation security baseline (no PATs, no client secrets).
* `copilot-instructions.md` Pipeline Mode reads as provider-agnostic.
* Acknowledgement gate runs identically for both providers.
* Documented ADO equivalents exist for: identity, secrets, environments, triggers, PR comments, artifacts, and approvals.
