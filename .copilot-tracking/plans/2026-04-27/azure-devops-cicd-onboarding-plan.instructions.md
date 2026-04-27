---
applyTo: '.copilot-tracking/changes/2026-04-27/azure-devops-cicd-onboarding-changes.md'
---
<!-- markdownlint-disable-file -->
# Implementation Plan: Add Azure DevOps as a CI/CD Option in Onboarding Agent

## Overview

Extend the existing `/git-ape-onboarding` agent and skill with a `cicd` parameter so users can pick GitHub Actions (current default), Azure DevOps Pipelines, or both, and add a sibling `.azure-pipelines/` example tree mirroring the four GitHub workflows.

## Objectives

### User Requirements

* Modify the onboarding agent so it implements Azure DevOps as CI/CD also — Source: user request 2026-04-27 ("modify the onboarding agent so it implements azure devops as CI CD also")
* Investigate and document what changes — Source: user request 2026-04-27 ("Check what can be done, and what needs to be changed, dont update anything") — note: research-only constraint applied to the prior research phase; this plan is a planning artifact only and does not modify production files until user runs implementation.

### Derived Objectives

* Keep the single-entry-point UX (`/git-ape-onboarding`) — Derived from: avoiding duplicated acknowledgement and compliance flows; aligns with research Scenario A selection.
* Reuse the same Entra App + RBAC + acknowledgement scaffolding for both providers — Derived from: minimising surface area and security drift; both providers can share the same App Registration with two federated credential sets.
* Replace the `/deploy` PR-comment trigger with ADO Environment manual approval check in ADO mode — Derived from: ADO has no native `issue_comment` trigger; environment approvals are the closest semantic match.
* Replace `codeql-action/upload-sarif` with pipeline-artifact-only output in ADO mode — Derived from: SARIF upload is a GitHub Advanced Security feature unavailable to ADO.
* Ask whether the repo lives in Azure Repos or GitHub when ADO mode is selected — Derived from: PR-comment-posting REST API differs between the two repo backends.

## Context Summary

### Project Files

* `.github/agents/git-ape-onboarding.agent.md` - Onboarding agent definition; 12-step workflow currently bound to GitHub primitives.
* `.github/skills/git-ape-onboarding/SKILL.md` - Onboarding skill playbook; the source of truth for setup logic. Steps 4, 5, 7, 8, 11 are GitHub-shaped.
* `.github/skills/prereq-check/SKILL.md` - Validates `az`, `gh`, `jq`, `git`. Needs `az devops` extension check when ADO mode selected.
* `.github/copilot-instructions.md` - Contains "Pipeline Mode (GitHub Actions)" section (lines ~163–270) and "OIDC Setup for GitHub Actions" auth section (line ~381). Both need provider-agnostic restructuring + sibling ADO sections.
* `.github/workflows/git-ape-plan.exampleyml` - Reference for the ADO plan pipeline.
* `.github/workflows/git-ape-deploy.exampleyml` - Reference for the ADO deploy pipeline (note `issue_comment` trigger has no ADO equivalent).
* `.github/workflows/git-ape-destroy.exampleyml` - Reference for the ADO destroy pipeline.
* `.github/workflows/git-ape-verify.exampleyml` - Reference for the ADO verify pipeline.
* `docs/ONBOARDING.md` - User-facing onboarding doc.
* `website/docs/getting-started/onboarding.md` - Website onboarding doc.
* `website/docs/agents/git-ape-onboarding.md` - Website agent doc.
* `website/docs/skills/git-ape-onboarding.md` - Website skill doc.

### References

* `.copilot-tracking/research/2026-04-27/azure-devops-cicd-onboarding-research.md` - Primary research document with primitive map, gaps, and selected approach (Scenario A).
* https://learn.microsoft.com/azure/devops/pipelines/library/connect-to-azure - ADO workload identity federation.
* https://learn.microsoft.com/azure/devops/pipelines/process/environments - ADO Environments + approvals.
* https://learn.microsoft.com/azure/devops/pipelines/library/variable-groups - ADO variable groups for secrets.
* https://learn.microsoft.com/rest/api/azure/devops/git/pull-request-threads - ADO PR comment REST API.
* https://learn.microsoft.com/cli/azure/devops - `az devops` CLI reference.

### Standards References

* `.github/copilot-instructions.md` § Azure Authentication — Auth Method Priority table dictates OIDC/workload identity federation as the only acceptable mechanism for both providers.
* `.github/copilot-instructions.md` § Security Gate Re-Run Rule — applies regardless of CI provider.

## Implementation Checklist

### [ ] Implementation Phase 1: Onboarding Agent + Skill Provider Branching

<!-- parallelizable: true -->
<!-- Note: Step 1.1 defines the provider-selection contract used by Step 1.2; resolve that contract first (decide parameter name, value enum, and how the skill receives it) before parallelising the file edits. -->

* [ ] Step 1.1: Add CI/CD provider selection to onboarding agent
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 13-44)
* [ ] Step 1.2: Branch the skill playbook by provider (includes Contribute-permission grant step)
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 46-94)
* [ ] Step 1.3: Add `az devops` extension and login check to prereq-check skill
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 96-115)

### [ ] Implementation Phase 2: ADO Pipeline Example Files

<!-- parallelizable: true -->

* [ ] Step 2.1: Create `.azure-pipelines/git-ape-plan.examplepipeline.yml`
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 119-148)
* [ ] Step 2.2: Create `.azure-pipelines/git-ape-deploy.examplepipeline.yml`
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 150-178)
* [ ] Step 2.3: Create `.azure-pipelines/git-ape-destroy.examplepipeline.yml`
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 180-202)
* [ ] Step 2.4: Create `.azure-pipelines/git-ape-verify.examplepipeline.yml`
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 204-220)

### [ ] Implementation Phase 3: Documentation Updates

<!-- parallelizable: true -->

* [ ] Step 3.1: Restructure `copilot-instructions.md` Pipeline Mode section to be provider-agnostic
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 224-253)
* [ ] Step 3.2: Add "OIDC Setup for Azure DevOps" auth section to `copilot-instructions.md`
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 255-275)
* [ ] Step 3.3: Update `docs/ONBOARDING.md` with ADO branch
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 277-292)
* [ ] Step 3.4: Update website docs (onboarding + agent + skill pages)
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 294-314)
* [ ] Step 3.5: Update `.github/agents/git-ape.agent.md` to reference both pipeline modes
  * Details: .copilot-tracking/details/2026-04-27/azure-devops-cicd-onboarding-details.md (Lines 316-332)

### [ ] Implementation Phase 4: Validation

<!-- parallelizable: false -->

* [ ] Step 4.1: Markdown lint and link check on all modified files
  * Run repo's standard markdown lint (`mega-linter` config) over the changed `.md` and `.yml` files.
* [ ] Step 4.2: YAML schema validation on `.azure-pipelines/*.examplepipeline.yml`
  * Validate with ADO's local schema (`az pipelines validate` against a sandbox project, or `actionlint`-equivalent for ADO if available; otherwise rely on `yamllint`).
* [ ] Step 4.3: Manual end-to-end dry-run of ADO branch on a sandbox subscription + sandbox ADO org
  * Verify federated credential subject `sc://<org>/<project>/<conn>` actually authenticates AzureCLI@2.
  * Verify variable group is created and pipeline can read `AZURE_SUBSCRIPTION_ID`.
  * Verify `az deployment sub validate` and `what-if` complete successfully.
  * Verify PR-thread comment posts to either Azure Repos or GitHub depending on repo backend.
* [ ] Step 4.4: Report blocking issues
  * Document anything requiring further research (notably: `metadata.json` `destroy-requested` detection logic in ADO, and Defender for DevOps SARIF integration).
  * Defer larger fixes to a follow-up planning cycle.

## Planning Log

See `.copilot-tracking/plans/logs/2026-04-27/azure-devops-cicd-onboarding-log.md` for discrepancy tracking, implementation paths considered, and suggested follow-on work.

## Dependencies

* `az` CLI ≥ 2.50 with `azure-devops` extension installed (`az extension add -n azure-devops`).
* `gh` CLI ≥ 2.0 (still required for GitHub side and for resolving repo metadata when ADO points at a GitHub repo).
* Azure subscription Owner or User Access Administrator on target subscription(s).
* Azure DevOps organization with Project Collection Administrator privileges (to create service connections + variable groups + environments).
* Entra ID tenant permission to create App Registrations (or reuse existing app from initial GitHub onboarding).
* User must understand both providers maintain identical security posture (workload identity federation only; no PATs or client secrets stored).

## Success Criteria

* `/git-ape-onboarding` accepts `cicd github|ado|both` parameter and asks the user when not provided — Traces to: User Requirement "implement Azure DevOps as CI/CD also".
* Selecting `ado` produces a working service connection, variable group, environment, and four committed `.yml` pipelines under `.azure-pipelines/` — Traces to: Research § "Files That Need to Change".
* `copilot-instructions.md` Pipeline Mode section explains both providers without favouring one — Traces to: Research § "Files That Need to Change".
* Acknowledgement gate (three "Yes" answers) still runs identically for both providers — Traces to: Derived Objective "reuse the same … acknowledgement scaffolding".
* No client secrets or PATs are introduced anywhere in the ADO branch — Traces to: `.github/copilot-instructions.md` § Azure Authentication.
* The `metadata.json` destroy flow has a documented ADO trigger path (or is explicitly listed as follow-up work) — Traces to: Research § "Potential Next Research" item 4.
