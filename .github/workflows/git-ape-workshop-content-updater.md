---
description: |
  Weekly agentic workshop-content maintenance for Git-Ape. Assesses the gap
  between the repository's current features (agents, skills, core workflows) and
  the existing workshop content, then proposes user-centric content updates as a
  draft pull request and a rolling coverage-status issue. This is the Phase 2
  (LLM content regeneration) counterpart to the deterministic
  git-ape-workshop-sync.yml issue-filer and the git-ape-deck-build.yml renderer.

strict: false

on:
  # Weekly (fuzzy: gh-aw distributes the exact minute to avoid load spikes).
  # Assess what workshop work is needed vs. the current state of the features.
  schedule: weekly on monday
  workflow_dispatch:
    inputs:
      focus:
        description: "Optional: scope the assessment to a feature or track (e.g. 'azure-cost-estimator' or 'Track 3'). Leave blank to assess everything."
        required: false
        default: ""

permissions:
  contents: read
  issues: read
  pull-requests: read

# Deterministic pre-step runs OUTSIDE the agent sandbox. It builds an
# authoritative inventory of features vs. workshop coverage so the agent
# reasons from ground truth and cannot hallucinate what is or isn't covered.
steps:
  - name: Build workshop coverage inventory
    shell: bash
    run: |
      set -uo pipefail
      mkdir -p .workshop-snapshots

      # Best-effort history deepen so per-file "last change" dates are meaningful.
      # Safe to fail on shallow clones / no network — staleness then degrades to
      # "unknown" and the agent leans on the workshop-sync issues + content reads.
      git fetch --deepen=400 --quiet 2>/dev/null || true

      AGENTS_DIR=".github/agents"
      SKILLS_DIR=".github/skills"
      WS="workshops"
      CORE_WORKFLOWS="git-ape-plan git-ape-deploy git-ape-destroy git-ape-verify"

      INV=".workshop-snapshots/WORKSHOP-INVENTORY.md"

      last_date() { git log -1 --format=%cs -- "$1" 2>/dev/null || true; }
      # Count workshop markdown files that mention a feature slug (read-only grep).
      refs_for() {
        grep -rIl --include='*.md' -e "$1" "$WS" 2>/dev/null | wc -l | tr -d ' '
      }

      {
        echo "# Workshop Coverage Inventory"
        echo ""
        echo "**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "**Workspace:** $GITHUB_WORKSPACE"
        echo ""
        echo "> This file is AUTHORITATIVE. The agent MUST read it before assessing"
        echo "> coverage. If it exists, the pre-step ran successfully — do not claim"
        echo "> the inventory is missing. Reference counts are a coarse grep proxy"
        echo "> (\`grep -l <slug> workshops/**\`); 0 refs is a strong signal a feature"
        echo "> is uncovered, but always confirm by reading the actual content."
        echo ""

        echo "## Workshop tracks present"
        echo ""
        for d in "$WS"/track-*/; do
          [ -d "$d" ] || continue
          labs=$(ls "$d"lab-*.md 2>/dev/null | wc -l | tr -d ' ')
          deck=$(ls "$d"*_deck.md 2>/dev/null | head -1)
          echo "- \`$d\` — ${labs} lab file(s); deck: \`${deck:-none}\`"
        done
        echo ""
        echo "Glossary: \`$WS/shared/glossary.md\` ($( [ -f "$WS/shared/glossary.md" ] && echo present || echo MISSING ))"
        echo ""

        echo "## Agents -> workshop coverage"
        echo ""
        echo "| Agent | Last change | Refs in workshops/ | Signal |"
        echo "|---|---|---|---|"
        for f in "$AGENTS_DIR"/*.md; do
          [ -f "$f" ] || continue
          base=$(basename "$f"); slug=${base%.agent.md}; slug=${slug%.md}
          d=$(last_date "$f"); refs=$(refs_for "$slug")
          if [ "$refs" = "0" ]; then sig="UNCOVERED — candidate for NEW content"; else sig="covered ($refs file(s))"; fi
          echo "| \`$slug\` | ${d:-unknown} | $refs | $sig |"
        done
        echo ""

        echo "## Skills -> workshop coverage"
        echo ""
        echo "| Skill | Last change | Refs in workshops/ | Signal |"
        echo "|---|---|---|---|"
        for sd in "$SKILLS_DIR"/*/; do
          [ -d "$sd" ] || continue
          slug=$(basename "$sd")
          d=$(last_date "${sd}SKILL.md"); refs=$(refs_for "$slug")
          if [ "$refs" = "0" ]; then sig="UNCOVERED — candidate for NEW content"; else sig="covered ($refs file(s))"; fi
          echo "| \`$slug\` | ${d:-unknown} | $refs | $sig |"
        done
        echo ""

        echo "## Core workflows -> workshop coverage (Track 3 CI/CD)"
        echo ""
        echo "| Workflow | Last change | Refs in workshops/ |"
        echo "|---|---|---|"
        for w in $CORE_WORKFLOWS; do
          wf=".github/workflows/${w}.yml"
          [ -f "$wf" ] || continue
          d=$(last_date "$wf"); refs=$(refs_for "$w")
          echo "| \`$w\` | ${d:-unknown} | $refs |"
        done
        echo ""

        echo "## Recently changed feature files (last 30 days, if history available)"
        echo ""
        git log --since="30 days ago" --name-only --pretty=format: -- \
          "$AGENTS_DIR" "$SKILLS_DIR" \
          .github/workflows/git-ape-plan.yml \
          .github/workflows/git-ape-deploy.yml \
          .github/workflows/git-ape-destroy.yml \
          .github/workflows/git-ape-verify.yml 2>/dev/null \
          | grep -E '\.(md|yml)$' | sort -u | sed 's/^/- /' || echo "- (no history available — rely on open workshop-sync issues)"
        echo ""
      } > "$INV"

      echo "---- WORKSHOP-INVENTORY.md ----"
      cat "$INV"

tools:
  edit:
  bash:
    - "ls *"
    - "cat *"
    - "find *"
    - "grep *"
    - "head *"
    - "tail *"
    - "wc *"
    - "sort *"
    - "diff *"
    - "jq *"
    - "date *"
    - "git log *"
    - "git diff *"
    - "git show *"
    - "git status *"
    - "git ls-files *"
  github:
    # Public repo: keep lockdown ON (the safe default). It sanitizes the
    # untrusted issue/PR content this agent reads (issues/pull_requests
    # toolsets), closing the cross-prompt-injection (XPIA) surface. Reading
    # issues/PRs lets the agent find open workshop-sync issues and avoid
    # opening duplicate content PRs.
    lockdown: true
    toolsets: [issues, pull_requests]
  cache-memory:
    description: "Workshop coverage state — remembers prior assessments and the last-seen feature set to keep weekly runs idempotent and avoid re-proposing already-open work."

safe-outputs:
  mentions: false
  allowed-github-references: []
  # Rolling coverage-status issue: the "what needs doing" assessment, produced
  # on EVERY run. Distinct title-prefix + label so close-older-issues never
  # touches the deterministic git-ape-workshop-sync.yml issues.
  create-issue:
    title-prefix: "[workshop-coverage] "
    labels: [workshop-coverage, report]
    close-older-issues: true
    max: 1
  # Draft PR with the actual content changes, opened only when gaps warrant it.
  # Rendered binaries are excluded so git-ape-deck-build.yml re-renders them
  # from the merged source — this workflow only edits source (.md) content.
  create-pull-request:
    title-prefix: "[workshop-update] "
    labels: [workshop-sync, workshop]
    draft: true
    max: 1
    if-no-changes: "ignore"
    auto-close-issue: false
    excluded-files:
      - "**/*.pdf"
      - "**/*.pptx"
      - "**/*.html"
      - "**/*.pptx-html"
    max-patch-files: 200
    max-patch-size: 2048
---

# Workshop Content Auto-Updater

Keep the Git-Ape workshop program continuously aligned with the product. Each
week, assess the gap between the repository's **current features** and the
**existing workshop content**, then propose **user-centric** updates for human
review. You never deploy, merge, or modify CI — you only propose content.

## Context

Git-Ape ships a four-track workshop program under `workshops/`. Today two
deterministic workflows keep it fresh:

- `git-ape-workshop-sync.yml` files a rolling **`workshop-sync` issue** listing
  feature files that changed on `main`.
- `git-ape-deck-build.yml` re-renders deck binaries (HTML/PDF/PPTX) when source
  changes.

You are the **Phase 2** layer those workflows anticipated: you reason about what
the content *should say* and propose the edits. You **augment** them — you do not
replace them.

## STEP 0 — MANDATORY: read the inventory first

The pre-step wrote an authoritative inventory to the workspace. Begin by running:

```bash
ls -la .workshop-snapshots/
cat .workshop-snapshots/WORKSHOP-INVENTORY.md
```

If `WORKSHOP-INVENTORY.md` exists, the pre-step ran successfully — never claim it
is missing. The inventory's reference counts are a coarse `grep` proxy: a `0` is a
strong signal a feature is uncovered, but always confirm by reading the real
content before concluding anything.

## STEP 1 — Gather change signals

1. Read the inventory's coverage tables and "recently changed feature files".
2. Use the GitHub tools to read **open `workshop-sync` issues** — they enumerate
   feature files that changed recently. Treat those as priority work items.
3. Read the most recent **`[workshop-coverage]` status issue** (if any) and your
   **cache memory** to recall what you already proposed, so you don't repeat
   open work.
4. If a `focus` input was provided (`${{ github.event.inputs.focus }}`), scope
   your assessment to that feature or track only.

## STEP 2 — Read the current workshop content

For every feature you intend to touch, read the actual content so your edits are
grounded and minimal-surprise:

- `workshops/README.md` — program overview and track selector.
- `workshops/track-1-zero-to-deploy/` — beginners / non-technical (30 min).
- `workshops/track-2-deploy-like-a-pro/` — engineers & developers (60 min).
- `workshops/track-3-platform-engineering/` — DevOps / SRE / platform (130 min).
- `workshops/track-4-executive-briefing/` — leads & executives (20 min, deck-led).
- `workshops/shared/glossary.md` — terms, agents, and skills reference.
- The relevant `lab-*.md`, `*_deck.md`, and `deck-outline.md` files.

Also read the **source** of each changed/uncovered feature
(`.github/agents/<name>.agent.md`, `.github/skills/<name>/SKILL.md`, or the core
workflow YAML) to understand what it actually does.

## STEP 3 — Classify the work

**Scope filter (apply first).** Not every uncovered feature deserves workshop
content. The program is **Azure-focused** and persona-driven. Before proposing
anything, drop features that are out of the workshop's current scope — for
example, the `aws-*` skills show as "uncovered" only because the program targets
Azure; do **not** generate content for them unless the program's scope has
deliberately expanded (a human signals this, e.g. via a `workshop-sync` issue or
the `focus` input). Prioritize features that are new/changed **and** fit an
existing persona.

Sort every remaining gap into one of three buckets:

- **New feature, uncovered** (0 refs in `workshops/`): a new agent/skill/workflow
  with no workshop coverage. Create new content for it (a new lab section, or a
  new lab, or — rarely — a new track).
- **Existing feature, changed** (referenced, but the feature changed after the
  content): the behaviour/output/name drifted. Revise the affected
  labs/decks/glossary so they match current behaviour.
- **In sync**: covered and unchanged. Leave it alone.

## STEP 4 — Choose the user-centric persona (infer, document, ask if unsure)

For each feature you will cover, infer **the user who benefits most** and map them
to the best-fit track, then write *for that persona*:

| Persona | Track | Lens |
|---|---|---|
| Beginner / non-technical | Track 1 | "Deploy with a single sentence" — no jargon, no Azure required |
| Engineer / developer | Track 2 | Security gates, cost, architecture, drift — hands-on with a sandbox |
| DevOps / SRE / platform | Track 3 | CI/CD, headless, multi-env, policy, drift ops, evals |
| Engineering lead / executive | Track 4 | Governance, cost visibility, compliance, ROI — deck-led |

Inference rules of thumb (confirm against the feature's actual purpose):

- Cost / pricing / ROI features → Track 2 (hands-on) and Track 4 (narrative).
- Security / policy / compliance features → Track 2 (deep dive) and Track 3 (gates).
- CI/CD, headless, multi-environment, drift, evaluation features → Track 3.
- Onboarding / first-deploy / natural-language features → Track 1.
- A foundational capability may justify coverage in **multiple** tracks at the
  appropriate depth for each persona.

If the right persona/track is genuinely ambiguous, **do not guess silently** —
state the options and your recommendation in the coverage-status issue and the PR
body, and pick the most defensible option so a human can redirect you.

## STEP 5 — Generate or revise content (section-level)

Work at the **section level**: rewrite the affected sections/labs and add new ones;
keep unaffected content intact. Reimagine thoughtfully by studying how the existing,
complete labs are structured (objectives → prerequisites → numbered steps →
expected output → recap → no-Azure fallback) and match that voice, depth, and
timing.

You MAY create or modify:

- Lab files (`workshops/track-*/lab-*.md`), including **new** labs.
- Deck source (`workshops/track-*/*_deck.md`) and `deck-outline.md`.
- `workshops/shared/glossary.md`, track `README.md`s, and `workshops/README.md`.
- Shared resources under `workshops/shared/` (prerequisites, troubleshooting, etc.).
- A **new track** directory (`workshops/track-N-<slug>/`) only when a feature set
  is large enough that it does not fit any existing persona/track — justify it
  explicitly in the PR body.
- The Docusaurus mirrors under `website/docs/workshops/` when their track changed.

You MUST NOT:

- Edit, delete, or hand-write rendered binaries (`*.pdf`, `*.pptx`, `*.html`) —
  `git-ape-deck-build.yml` regenerates those from the merged source.
- Modify any file outside `workshops/` and `website/docs/workshops/` — never touch
  `.github/`, source code, or this workflow.
- Modify deck CSS front-matter or remove existing slides/labs.
- Break a lab's stated timing (30/60/130/20 min) or its no-Azure fallback path.
- Invent feature behaviour. Every described command, output, agent, or skill must
  be verifiable against the feature source you read. When unsure, say so rather
  than fabricate.

### Deck lint rules (when editing `*_deck.md`)

The renderer enforces these — keep them satisfied so the build won't fail:

- **L1** — No inline `<svg>`. Reference external files at
  `workshops/shared/img/<name>.svg` via `<img src="../shared/img/...">`.
- **L11** — Marp class directives (`<!-- _class: ... -->`) live in their own
  comment block, separate from speaker notes.
- **L15** — No trailing `---` at end of file (it creates an empty slide).

## STEP 6 — Outputs

### Always: rolling coverage-status issue (`create_issue`)

Produce **exactly one** coverage-status issue every run (it rolls — older
`[workshop-coverage]` issues auto-close). Use `###`/`####` headers only. Format:

```markdown
### Workshop Coverage Status — <YYYY-MM-DD>

**Run:** <workflow-run-url>
**Features assessed:** <n agents, n skills, n workflows>
**Coverage:** <covered> / <total> · **Gaps found:** <count>
**Proposed this run:** <draft PR #__ | none — in sync>

### Gaps & proposed work
| Feature | Type | Persona / Track | Action | Status |
|---|---|---|---|---|
| `azure-cost-estimator` | skill | Engineer / T2 | New lab section | In PR #__ |
| ... | ... | ... | ... | deferred / in sync |

<details><summary><b>Coverage detail</b></summary>
...per-feature notes, including any persona ambiguity and your recommendation...
</details>

### Recommended next steps
- ...
```

### When work is warranted: a draft PR (`create_pull_request`)

If — and only if — you made content changes, open a **draft** PR. If everything is
in sync, make no changes (the PR step is skipped automatically). The PR body must:

- Summarize what changed and **why**, per feature.
- Name the **persona/track** each change targets and your reasoning.
- Confirm the guardrails (timing preserved, no-Azure fallback intact, binaries
  untouched, lint rules satisfied).
- Link the coverage-status issue, and add `Closes #<n>` for any **open
  `workshop-sync` issue** this PR resolves (so merging clears the deterministic
  backlog item). Do **not** add `Closes` for the rolling coverage-status issue.

## STEP 7 — Update memory

Record in cache memory: this run's timestamp, the feature set you assessed, the
gaps found, and what you proposed (issue/PR). On the next run, use it to avoid
re-proposing work that is already in an open PR.

## Required completion behavior

- Always call `create_issue` exactly once (the rolling coverage report), even when
  everything is in sync ("no gaps — content matches current features").
- Call `create_pull_request` only when you actually changed content.
- The safe-output tools exist **only in this top-level agent context** — never
  delegate them to a subagent or skill. Do the work yourself and call them in your
  final turn.
