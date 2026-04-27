<!-- markdownlint-disable-file -->
# Release Changes: Add Azure DevOps as a CI/CD Option in Onboarding Agent

**Related Plan**: azure-devops-cicd-onboarding-plan.instructions.md
**Implementation Date**: 2026-04-27

## Summary

Extends the `/git-ape-onboarding` agent and skill so users can pick GitHub Actions, Azure DevOps Pipelines, or both as the Git-Ape CI/CD provider, and adds a sibling `.azure-pipelines/` example tree mirroring the four existing GitHub workflow examples.

## Changes

### Added

- `.azure-pipelines/git-ape-plan.examplepipeline.yml` — ADO PR-trigger pipeline mirroring `git-ape-plan.exampleyml`. Detects changed deployments via `git diff` against `$(System.PullRequest.TargetBranch)`, runs `az deployment sub validate` + `what-if` via `AzureCLI@2` (OIDC service connection `git-ape-azure`), executes Checkov / ARM-TTK / PSRule scans, posts plan as PR thread via `$(System.AccessToken)` against the Azure Repos Threads REST API, and publishes plan artifacts. Uses matrix-over-deployments via `dependencies.detect_deployments.outputs['find.DEPLOYMENT_IDS']`.
- `.azure-pipelines/git-ape-deploy.examplepipeline.yml` — ADO CI pipeline (trigger on `main` with deployment path filter) mirroring `git-ape-deploy.exampleyml`. Three stages: `Detect`, `Validate`, `Deploy` (gated by `environment: azure-deploy` for manual approval — replaces GitHub `/deploy` comment). Runs `az deployment sub create` sequentially per deployment, executes integration tests, writes `state.json`, and commits state back to `main` via `$(System.AccessToken)` + `git push` (no PAT). References variable group `git-ape-azure-secrets` for `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`.
- `.azure-pipelines/git-ape-destroy.examplepipeline.yml` — ADO destroy pipeline mirroring `git-ape-destroy.exampleyml`. CI trigger on `metadata.json` / `state.json` changes proceeds only when `metadata.json` status equals `destroy-requested`. Manual run dispatch fallback exposes `parameters: deploymentId` + `confirmation` (allowed values restricted to `destroy` and empty string). Destroy stage gated by `environment: azure-destroy` for manual approval. Runs `az group delete --yes` and commits updated `state.json` / `metadata.json` via `$(System.AccessToken)`.
- `.azure-pipelines/git-ape-verify.examplepipeline.yml` — Manual-only ADO verification pipeline mirroring `git-ape-verify.exampleyml`. Validates required variables, exercises OIDC login via `AzureCLI@2`, lists RBAC role assignments for the federated principal, validates an empty subscription-scope deployment, and confirms `.azure-pipelines/*.yml` files exist.

### Modified

- `.github/agents/git-ape-onboarding.agent.md` — Phase 1 / Step 1.1: inserted Step 1.5 "Select CI/CD platform" plus a new `## CI/CD Platform Selection` section using a single `vscode_askQuestions` call to collect provider choice (GitHub Actions / Azure DevOps Pipelines / Both) and follow-up ADO inputs (`ado-org-url`, `ado-project`, `ado-source-repo` skipped when Both, `ado-connection-prefix`); extended Step 4 prereq validation to require `azure-devops` extension and reachable ADO org when ADO or Both is active; expanded Step 11 to cover both rename branches plus Step 11c grant; clarified that the acknowledgment gate is identical across providers.
- `.github/skills/git-ape-onboarding/SKILL.md` — Phase 1 / Step 1.2: branched the Command Playbook with `[shared]` / `[github]` / `[ado]` annotations on steps 2, 4, 5, 7, 8, 11 (no GitHub-only commands run unconditionally); added `Parameterized with CI/CD provider selection` execution mode (`/git-ape-onboarding cicd ado|both ...`); split Step 11 into Step 11a (GitHub rename), Step 11b (ADO rename + `az pipelines create` per file), and Step 11c (grant the project's build identity Contribute on the repo via `az devops security permission update` against the `Git Repositories` namespace, with documented skip + manual-portal-grant fallback for cross-project repo setups); added `Azure DevOps — provider-specific gotchas` subsection covering no `issue_comment` trigger, per-connection federated subject (`sc://<org>/<project>/<connection>`), no SARIF upload, the build-identity grant requirement, and workload-identity-federation-only auth posture (no PATs / client secrets / password credentials).
- `.github/skills/prereq-check/SKILL.md` — Phase 1 / Step 1.3: added Step 5.5 "If ADO selected — validate Azure DevOps toolchain" running `az extension show -n azure-devops`, `az devops configure --list`, and an optional `az devops user show` reachability check; added an ADO row to the Step 3 results table; documented `az extension add/update --name azure-devops` install commands for all platforms and the optional `az devops configure --defaults` step; updated Step 6 summary and Agent Behavior so `✅ READY` requires Step 5.5 to pass when ADO mode is active.
- `.github/copilot-instructions.md` — Restructured `### Pipeline Mode` section to be provider-agnostic with `#### Pipeline Mode (GitHub Actions)` and `#### Pipeline Mode (Azure DevOps Pipelines)` subsections (Step 3.1). Demoted workflow headings from `####` to `#####` under the GitHub subsection. Added new ADO subsections for `git-ape-plan.yml`, `git-ape-deploy.yml`, `git-ape-destroy.yml`, and `git-ape-verify.yml`, each documenting trigger differences (no `issue_comment`), Environment-based approval gate, and pipeline-artifact-only verification (no SARIF upload). Added `### OIDC Setup for Azure DevOps Pipelines` subsection mirroring the GitHub one (Step 3.2). Updated Auth Method Priority table row 1 to read "GitHub Actions / Azure DevOps Pipelines / Copilot Coding Agent" with both `azure/login@v2` and `AzureCLI@2` workload-identity-federation references.
- `docs/ONBOARDING.md` — Reworded intro to support repositories on either provider, added `## Choosing your CI/CD provider` section with a comparison table near the top, and appended a Troubleshooting entry for ADO `TF400813` / "Service connection authorization failed" diagnosis (Step 3.3).
- `website/docs/getting-started/onboarding.md` — Mirrored the docs/ONBOARDING.md changes (provider-agnostic intro, provider comparison table, ADO troubleshooting entry) using Docusaurus `:::note` admonition, preserving frontmatter (Step 3.4).
- `website/docs/agents/git-ape-onboarding.md` — Regenerated from updated `.github/agents/git-ape-onboarding.agent.md` source via `node scripts/generate-docs.js`, surfacing the new `cicd` parameter, ADO branching, and ADO acknowledgment wording (Step 3.4).
- `website/docs/skills/git-ape-onboarding.md` — Regenerated from updated `.github/skills/git-ape-onboarding/SKILL.md` source via `node scripts/generate-docs.js`, surfacing the branched playbook for ADO, both, and GitHub providers (Step 3.4).
- `website/docs/agents/git-ape.md` — Regenerated from updated `.github/agents/git-ape.agent.md` source (Step 3.5 cascade).
- `.github/agents/git-ape.agent.md` — Updated Headless Mode section to read "Copilot Coding Agent / GitHub Actions / Azure DevOps Pipelines"; replaced "GitHub Actions workflows handle the rest" with "the configured CI/CD provider's pipeline workflows handle the rest"; added `TF_BUILD` mode-detection rule; updated Workflow Differences table and constraints footer to reference both providers without leaking provider-specific technical detail into the orchestrator (Step 3.5).

### Removed

None.

## Additional or Deviating Changes

- DD-01 (per-environment service-connection model): plan deviates from research's per-env-app suggestion. Implementation reuses a single Entra App across environments and creates one service connection per environment. Symmetric with current GitHub onboarding posture; tracked in planning log.
- DD-02 (SARIF upload omitted in ADO mode): `git-ape-plan.examplepipeline.yml` publishes Checkov / ARM-TTK / PSRule scan results as pipeline artifacts only. Microsoft Defender for DevOps SARIF integration deferred to WI-02.
- DD-03 (`/deploy` PR-comment trigger replaced by ADO Environment approval): `git-ape-deploy.examplepipeline.yml` does not implement a comment-triggered pre-merge deploy path. Environment manual approval check on the deploy stage is the gating mechanism. Documented in `copilot-instructions.md` Pipeline Mode (Azure DevOps) and in agent file.
- Auto-regenerated website docs: `scripts/generate-docs.js` was run to regenerate `website/docs/agents/git-ape.md`, `website/docs/agents/git-ape-onboarding.md`, and `website/docs/skills/git-ape-onboarding.md` from their source `.agent.md` / `SKILL.md` files. This is the documented mechanism for those auto-generated pages.
- Phase 2 Step 2.2 deploy pipeline iterates the deployment-IDs JSON list **sequentially inside one approved environment run** rather than fanning out via `strategy: matrix:`. Reason: ADO `deployment` jobs cannot combine a runtime-expanded matrix with environment gating in the same job. Behaviour matches the GitHub workflow's `max-parallel: 1` constraint. Documented in the pipeline file header.
- Phase 2 Step 2.1 plan pipeline PR-comment posting targets Azure Repos via `$(System.AccessToken)`. The GitHub-backed-ADO variant (POST to `https://api.github.com/repos/<owner>/<repo>/issues/<pr>/comments` via a GitHub service-connection token) is referenced in details Step 2.1 but not implemented in the example file. Tracked as Phase 2 Suggested Step 4 in the planning log follow-up backlog.
- Phase 4 Step 4.3 manual end-to-end ADO dry-run on a sandbox subscription + ADO org was not executed in this implementation cycle (no sandbox infrastructure available). Tracked as a follow-up validation item.
- Step 11c grant uses `az devops security permission update` against the `Git Repositories` namespace. Some older `azure-devops` extension builds expose only `az devops invoke` against the `securitynamespaces` / `accesscontrolentries` resources; the playbook documents the modern surface. If the prereq-check Step 5.5 detects an old extension build, the user is prompted to upgrade via `az extension update --name azure-devops`.

## Release Summary

**Total files affected**: 11 (4 added, 7 modified) excluding tracking artifacts.

**Files added** (4) — all under new `.azure-pipelines/` directory mirroring the four `.github/workflows/git-ape-*.exampleyml` files:

- `.azure-pipelines/git-ape-plan.examplepipeline.yml`
- `.azure-pipelines/git-ape-deploy.examplepipeline.yml`
- `.azure-pipelines/git-ape-destroy.examplepipeline.yml`
- `.azure-pipelines/git-ape-verify.examplepipeline.yml`

**Files modified** (7):

- `.github/agents/git-ape-onboarding.agent.md` — provider selection step + ADO acknowledgment parity
- `.github/agents/git-ape.agent.md` — provider-agnostic orchestration wording + `TF_BUILD` detection
- `.github/skills/git-ape-onboarding/SKILL.md` — branched playbook with `[shared]` / `[github]` / `[ado]` annotations + Step 11a/b/c
- `.github/skills/prereq-check/SKILL.md` — `az devops` extension + reachability check
- `.github/copilot-instructions.md` — provider-agnostic Pipeline Mode + new ADO OIDC Setup section + updated Auth Method Priority table
- `docs/ONBOARDING.md` — provider comparison + ADO troubleshooting
- `website/docs/getting-started/onboarding.md` — mirrored Docusaurus version
- `website/docs/agents/git-ape.md`, `website/docs/agents/git-ape-onboarding.md`, `website/docs/skills/git-ape-onboarding.md` — regenerated from sources

**Dependency / infrastructure changes**: none in production code. Onboarding now depends on the `azure-devops` `az` extension (auto-installed by prereq-check Step 5.5 when ADO mode is selected). No new runtime dependencies, no new third-party services, no breaking changes to existing GitHub onboarding paths.

**Deployment notes**:

- Existing GitHub-only consumers see no behavioural change unless they explicitly choose `cicd ado|both` at onboarding.
- ADO mode requires a one-time setup: the user must have Project Collection Administrator on the target ADO project to allow service-connection + variable-group + environment + Contribute-permission writes.
- All ADO authentication uses workload identity federation (`AzureCLI@2` + `azureSubscription:` service-connection name). No PATs, no client secrets, no password credentials anywhere in the new code paths.
- Acknowledgment gate (three explicit "Yes" answers) is preserved unchanged for both providers.
- DD-01 / DD-02 / DD-03 deviations from research are documented in the planning log; consult that file for follow-up work items WI-01 through WI-06.
