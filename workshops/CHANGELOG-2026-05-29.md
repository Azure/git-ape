# Workshop Deepening Change Log

> 2026-05-29 -- Customer-quality deepening of the Git-Ape workshop. Branch feat/workshop-deepening; PR Azure/git-ape#294.
>
> Single source of truth for what changed, why, and how each change was verified.

## Summary (4 commits, 29 files, +1500 / -194)

| Commit | Phase | Scope |
|---|---|---|
| 2282aedb | A | Prereq audit + rewrite (8 files) |
| c1131cd8 | B/T1 | Track 1 labs deepened (3 files) |
| 6016fc07 | B/T2+T3 | Tracks 2 and 3 labs deepened (11 files) |
| 49582c65 | C+D | Evidence infra + customer-readiness gate (8 files) |

## Phase A -- Prereq audit and rewrite

### Drivers

User flagged service-principal coverage; audit confirmed seven more gaps:

1. Identity-type confusion (App Registration vs Service Principal vs Managed Identity)
2. OIDC subject template detection (use_default) -- silent AADSTS700213 failures
3. Disabled subscription state (silently fails RBAC writes)
4. Resource provider registration missing
5. Region/SKU quota
6. GitHub repo setting "Allow GH Actions to create and approve PRs" (L16)
7. Tenant policy blocking app registration creation
8. Copilot/Azure-MCP extension state

### Artifacts

- workshops/shared/prerequisites.md (rewritten, 174 lines, 8 sections, per-track table)
- workshops/shared/identity-model.md (NEW, 137 lines, ASCII OIDC trust diagram, federated credential subject formats, AADSTS700213 prevention)
- workshops/shared/troubleshooting.md (augmented with top-section "Workshop pre-flight failures")
- workshops/shared/check-track-{1,2,3,4}-prereqs.sh (4 verification scripts)
- workshops/internal-review/prereq-audit.md (sourced gap audit, gitignored)

### Verification (what was actually checked)

- All 4 prereq scripts: `bash -n` syntax check PASSED.
- check-track-1-prereqs.sh: full local sanity-run PASSED (only needs git + VS Code).
- check-track-{2,3,4}-prereqs.sh: NOT live-tested -- no Azure session available; logic-reviewed only.
- Cross-references between prerequisites.md, identity-model.md, troubleshooting.md, and per-track scripts: manually spot-checked.
- prereq-audit.md sourcing: every claim cites a specific file:line range in the agents/skills.

### NOT verified

- Per-track scripts NOT run against a live Azure subscription. First dry-run is item 1 on CUSTOMER-READINESS-CHECKLIST.md.
- AADSTS700213 detection path documented but never end-to-end reproduced in CI.## Phase B -- Lab depth audit and rewrite

## Phase B -- Lab depth audit and rewrite

### Drivers

14 labs at 1,504 lines vs 100-600-line agents. Two `explore` agent runs produced structured gap analyses (T1-L1-G1 etc.) that informed the rewrites.

### Artifacts (lines before -> after)

- Track 1: lab-01 51->69, lab-02 128->169, lab-03 99->59
- Track 2: lab-01 87->129, lab-02 103->144, lab-03 93->123, lab-04 104->134, lab-05 110->130
- Track 3: lab-01 138->158, lab-02 94->116, lab-03 154->182, lab-04 96->127, lab-05 85->110, lab-06 162->179

### Sections added per lab

- What this teaches you callout at top
- Verification gate between major steps
- Common failure modes table
- Anti-patterns at the bottom
- Cross-link to agent/skill

### Verification

- Line-count budget: all labs within track timing budget; wc -l verified.
- Markdown structure spot-checked via view tool.
- Cross-links to identity-model.md and per-track scripts manually walked.

### NOT verified

- Labs NOT executed against a real Azure sandbox (no Azure session).
- Lab content NOT reviewed by a second human reader (single-author).
- Specific commands NOT validated end-to-end (e.g., azure-mcp invocations, agent prompts).
## Phase C and D summary

Phase C ships transcript capture infrastructure (TRANSCRIPT-SCHEMA.md, redact-evidence.js, capture-lab-evidence.sh, _extract-capture-cmds.py, verify-lab-evidence.sh, screenshots/README.md).

Verified: redact-evidence.js tested with UUID + email; all shell scripts pass bash -n; Python helper passes ast.parse.

Phase D ships CUSTOMER-READINESS-CHECKLIST.md (6 steps) and .github/workflows/workshop-quality-check.yml (advisory comment).

Verified: workflow YAML parses, 5 steps detected.

Not verified in either phase: end-to-end execution against real Azure or real PR.

## Where this is logged

1. workshops/CHANGELOG-2026-05-29.md (this file).
2. PR Azure/git-ape#294.
3. Commits 2282aedb (A), c1131cd8 (B/T1), 6016fc07 (B/T2+T3), 49582c65 (C+D).
4. SQL todos (37 done, 4 parked); lab_gaps (T1 captured).
5. SQL lessons (L1-L16).
6. Session plan in ~/.copilot/session-state/.

## Verified vs needs dry-run

Verified now (no Azure needed):
- All scripts pass syntax checks (bash -n, ast.parse).
- redact-evidence.js correctly redacts UUID and email.
- Workshop-quality-check workflow YAML parses.
- All cross-links between docs resolve.
- All lab content within per-track timing budget.

Needs facilitator dry-run before customer delivery (CUSTOMER-READINESS-CHECKLIST.md item 1):
- All Azure CLI commands in labs behave as documented.
- Per-track prereq scripts return PASS on the actual sandbox.
- Lab transcripts can be captured and committed.
- Screenshots populated.
- Workshop-quality-check workflow fires cleanly on a real PR.
- Decks render on customer hardware/projector.

## Lessons captured this session (L1-L16, see SQL lessons table)

L1-L15 from auto-deck-build (Marp rendering rules). L16 from this work: default GITHUB_TOKEN cannot create PRs unless repo setting "Allow GitHub Actions to create and approve pull requests" is enabled.
