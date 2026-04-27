<!-- markdownlint-disable-file -->
# Planning Log: Add Azure DevOps as a CI/CD Option in Onboarding Agent

## Discrepancy Log

### Unaddressed Research Items

* DR-01: ADO has no native equivalent of GitHub's `issue_comment` trigger used for `/deploy` semantics.
  * Source: `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` (§ "Concrete Gaps and Mitigations" item 1)
  * Reason: Plan adopts the recommended mitigation (replace with ADO Environment approval check) rather than rebuilding `/deploy` semantics. The plan does not preserve the "deploy from branch before merge" behaviour that `/deploy` enables in GitHub mode.
  * Impact: medium — ADO users lose pre-merge deployment capability; deploy is gated on merge to `main` plus environment approval.

* DR-02: SARIF upload via `codeql-action/upload-sarif` is GitHub-only.
  * Source: Research § "Concrete Gaps and Mitigations" item 3
  * Reason: Plan replaces SARIF upload with pipeline-artifact-only output; integration with Microsoft Defender for DevOps for ADO is deferred.
  * Impact: medium — security findings still surface via plan PR comment, but are not aggregated in a security dashboard.

* DR-03: Org GUID resolution method may require a PAT in some ADO tenants when using `_apis/connectionData` from CI context.
  * Source: Research § "API and Schema Documentation" + § "Potential Next Research" item 2
  * Reason: Plan documents the unauthenticated `connectionData` approach but does not validate it across all tenant configurations.
  * Impact: low — falls back to manual one-time lookup during onboarding interview.

* DR-04: Whether `az devops invoke` reliably creates Environments + approval checks across ADO tenants is not verified.
  * Source: Research § "Potential Next Research" item 2
  * Reason: Plan assumes the REST path works; validation deferred to Phase 4.
  * Impact: medium — onboarding may need to fall back to manual ADO portal steps for environment creation in some tenants.

* DR-05 (resolved): `.github/agents/git-ape.agent.md` is listed by research as needing an update ("Reference both pipeline modes when explaining the orchestration flow") but was absent from the plan and details.
  * Source: Research § "Files That Need to Change" (last row)
  * Reason: Plan Phase 3 documentation step enumerated `copilot-instructions.md`, `docs/ONBOARDING.md`, and three website pages, but did not include `git-ape.agent.md`.
  * Resolution: Added Step 3.5 to plan and details (see plan checklist + details Lines 316-332).
  * Impact: was major; resolved.

* DR-06 (resolved): Onboarding step that grants build identity "Contribute" permission on the target repo was not specified.
  * Source: Research § "Concrete Gaps and Mitigations" item 4 ("onboarding must perform this grant via `az devops security permission update`")
  * Reason: Details Step 2.2 listed the requirement but no playbook step in Phase 1.2 issued the grant.
  * Resolution: Added Step 11c to the ADO branch in details Step 1.2 (under skill playbook step 11). Plan Step 1.2 title now annotates "includes Contribute-permission grant step".
  * Impact: was major; resolved.

* DR-07 (resolved): Matrix-over-deployments primitive translation is now documented.
  * Resolution: Plan details Phase 2 preamble specifies `strategy: matrix:` driven by an output variable from a detection job (consumed via `dependencies.<job>.outputs[...]`).

* DR-08: Subject claim format confirmation is not captured as follow-up.
  * Source: Research § "Potential Next Research" item 1 (some docs show `sc://<org>/<project>/<connection-id>` rather than connection-name)
  * Reason: Plan and details consistently use the connection-name form without flagging the open question.
  * Resolution: Tracked as WI-06 in Suggested Follow-On Work; Phase 4 dry-run will catch a connection-id-required tenant.
  * Impact: low.

### Plan Deviations from Research

* DD-01: Per-environment service-connection model.
  * Research recommends: one Entra app per environment (because ADO subjects are per-service-connection).
  * Plan implements: one Entra app shared across all envs in ADO mode, with one service connection (and therefore one federated credential on that one app) per env. The federated credentials are siblings, not separate apps.
  * Rationale: Reuses the existing GitHub onboarding's single-app model. Simplifies RBAC management. Trade-off: blast radius of an app compromise extends across all envs (same as GitHub mode today). Acceptable given documented production-not-yet acknowledgement.

* DD-02: SARIF upload step in `git-ape-plan.examplepipeline.yml` is omitted entirely (publishes scan results as pipeline artifact instead).
  * Research recommends: replacement via Microsoft Defender for DevOps native integration.
  * Plan implements: pipeline artifact only; Defender for DevOps integration deferred to follow-up.
  * Rationale: Defender for DevOps onboarding is itself a multi-step setup that doesn't belong in the same change as adding ADO support. Captured as WI-02.

* DD-03: `/deploy` comment trigger replaced by ADO Environment approval check.
  * Research recommends: use environment approval (Mitigation A — recommended in research).
  * Plan implements: same.
  * Rationale: Native ADO mechanism; no Function App glue. Documented as a UX deviation users must understand.

## Implementation Paths Considered

### Selected: Scenario A — Provider-Aware Single Onboarding Skill

* Approach: Add a `cicd github|ado|both` parameter to the existing `/git-ape-onboarding` skill and agent. Branch only the four steps that genuinely differ (federated credential, secrets, environments, workflow activation). Add a sibling `.azure-pipelines/` example tree.
* Rationale: Smallest change that preserves the single-entry-point UX and reuses the acknowledgement + compliance scaffolding. Symmetric with how ADO actually models OIDC.
* Evidence: Research document § "Selected approach — Scenario A".

### IP-01: Separate `git-ape-onboarding-ado` agent + skill

* Approach: Create a parallel agent and skill dedicated to ADO. Keep GitHub onboarding untouched.
* Trade-offs: Cleaner separation; no conditional logic. But the shared concerns (Entra app, RBAC, acknowledgements, compliance Q&A, prereq-check) duplicate. Two sets of acknowledgement prompts. Drift inevitable over time.
* Rejection rationale: Maintenance cost dominates the architectural cleanliness benefit.

### IP-02: Transpile GitHub workflows → ADO pipelines

* Approach: Use a converter to generate `.azure-pipelines/*.yml` from `.github/workflows/*.yml`.
* Trade-offs: Zero hand-written ADO YAML — but no production-grade converter handles `actions/github-script` or `gh` CLI. Output requires heavy manual fix-up.
* Rejection rationale: Fragile, adds a build dependency, and the four pipeline files are not so large that hand-authoring is uneconomical.

### IP-03: ADO-only (drop GitHub support)

* Approach: Migrate Git-Ape entirely off GitHub Actions.
* Trade-offs: Single CI surface area; loses GitHub-native UX (PR comments, `/deploy`, GHAS).
* Rejection rationale: Out of scope per user request ("also implement").

## Suggested Follow-On Work

* WI-01: Investigate `metadata.json` `destroy-requested` trigger reliability in ADO mode (priority: medium)
  * Source: Research § "Potential Next Research" item 4 + plan Phase 4.4
  * Dependency: this plan (`git-ape-destroy.examplepipeline.yml` exists first)

* WI-02: Integrate Microsoft Defender for DevOps SARIF aggregation for ADO mode (priority: medium)
  * Source: DD-02
  * Dependency: this plan (basic ADO pipelines exist first)

* WI-03: Validate `az devops invoke` Environments + Approval Checks REST creation across multiple ADO tenants (priority: low)
  * Source: DR-04
  * Dependency: this plan

* WI-04: Add `/deploy`-equivalent webhook + Function App to allow pre-merge deploys in ADO mode (priority: low — optional UX parity)
  * Source: DR-01 mitigation B
  * Dependency: this plan; only if user feedback demands it

* WI-05: Org GUID auto-resolution helper script for onboarding (priority: low)
  * Source: DR-03
  * Dependency: this plan

* WI-06: Confirm ADO federated-credential subject form (`connection-name` vs `connection-id`) across multiple tenants (priority: low)
  * Source: DR-08 / Research § "Potential Next Research" item 1
  * Dependency: this plan
