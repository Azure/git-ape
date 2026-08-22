# Workshop Deck Auto-Generation

> Marp decks for Tracks 1–4 are rebuilt automatically when source files change. This document explains the mechanism, triggers, idempotency guarantees, and how to disable it for a one-off manual edit.

## At a glance

```
┌──────────────────────────────────┐
│ push to main with deck.md /      │
│ shared SVG / agent / skill /     │
│ core workflow change             │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│ git-ape-deck-build.yml           │
│ 1. Detect affected tracks        │
│ 2. Lint deck.md (L1, L11, L15)   │
│ 3. Render html + pdf + pptx      │
│ 4. Rasterize pdf + pptx → PNGs   │
│ 5. Diff outputs; skip if no diff │
└──────────────┬───────────────────┘
               │ rendered files changed
               ▼
┌──────────────────────────────────┐
│ Open / update auto-PR            │
│ Branch: auto/deck-rebuild        │
│ Body: inline screenshots         │
│ Closes #<workshop-sync-issue>    │
└──────────────────────────────────┘
```

## Trigger paths

The workflow fires on `push` to `main` when any of the following change:

| Path | Behaviour |
|------|-----------|
| `workshops/track-*/*_deck.md` | Rebuild that single track |
| `workshops/shared/img/<file>.svg` | Rebuild every track whose deck.md references that file name |
| `.github/agents/**` | Render-smoke-test (rebuilds all tracks; no content update in Phase 1) |
| `.github/skills/**` | Render-smoke-test (rebuilds all tracks; no content update in Phase 1) |
| `.github/workflows/git-ape-{plan,deploy,destroy,verify}.yml` | Render-smoke-test (rebuilds all tracks) |
| `scripts/render-workshop-decks.js` or `scripts/verify-workshop-decks.js` | Rebuild every track (toolchain change) |

**Phase 1 honest framing**: Source-file triggers (`.github/agents/**`, `.github/skills/**`, core workflows) only run **render + verify** against the current `deck.md` content — they do **not** rewrite the deck text to reflect source changes. If `deck.md` is already in sync with the source, the render output will be byte-identical and **no PR is opened**. If there's a real visual change (e.g., new SVG, edited deck.md in the same commit), the PR is opened.

Deck-text regeneration is handled separately by the **Phase 2 agentic workflow**
(`git-ape-workshop-content-updater.md`, see below): it proposes content edits to
`deck.md` (and labs/glossary) on a weekly cadence, and the merge of that draft PR
then re-triggers this render workflow. Treat this render workflow's source-file
triggers as a heartbeat: they confirm the toolchain still produces a stable build.

**Track-rebuild scope**: When *any* trigger fires while an auto-PR is already open, the workflow rebuilds **all four tracks** instead of just the changed track. This prevents an earlier track's pending rendered changes from being dropped by a later partial rebuild on the same shared branch.

`workflow_dispatch` is also supported for manual runs. Use the `only` input (e.g., `T1,T2`) to scope a manual rebuild.

## Outputs

Each successful build produces, **on the `auto/deck-rebuild` branch only**:

- `workshops/track-<N>-<name>/<N>_<name>_deck.html`
- `workshops/track-<N>-<name>/<N>_<name>_deck.pdf`
- `workshops/track-<N>-<name>/<N>_<name>_deck.pptx`
- `.deck-screenshots/T<N>/pdf/slide-NN.png` (rasterized PDF, one per slide)
- `.deck-screenshots/T<N>/pptx/slide-NN.png` (PPTX → PDF → PNG, one per slide)
- `.deck-screenshots/manifest.json`

The auto-PR embeds the screenshots inline via `raw.githubusercontent.com` URLs so reviewers see every slide without leaving the PR page.

The full screenshot set is also uploaded as a workflow artifact (`workshop-deck-screenshots-<run_id>`) and retained for 14 days.

## Idempotency and loop prevention

- **Single long-lived branch**: every run pushes to the same branch (`auto/deck-rebuild`) with `--force-with-lease`. Multiple consecutive triggers update the same branch and the same PR — never spawn duplicates.
- **No-op detection**: if the rendered files are byte-identical to those on `main`, the workflow exits without committing or opening a PR.
- **Loop guard 1**: the workflow's `if:` filter skips runs authored by `github-actions[bot]`. The auto-PR merge commit will therefore not re-trigger the workflow.
- **Loop guard 2**: every auto-commit message contains `[skip deck-build]` as a belt-and-braces signal.
- **Lint fail-fast**: `render-workshop-decks.js` never mutates `deck.md`. If lint fails (e.g., trailing `---` per L15), the build exits with code 2 and a human must fix the source. No auto-mutation can create a feedback loop.

## Workshop-sync Issue auto-close

`.github/workflows/git-ape-workshop-sync.yml` opens an Issue labelled `workshop-sync` whenever a feature change might affect the workshop content. When the deck-build workflow opens a PR while such an Issue is open, the PR body contains `Closes #<number>`. Merging the auto-PR closes the Issue.

If no `workshop-sync` Issue is open, the PR body just lists the trigger paths — no Issue is created or referenced.

## How to opt out for a one-off manual edit

You may want to make a hand-tuned PDF/PPTX (for example, a customer-specific variant) without the auto-PR clobbering it. Two options:

1. **Suppress a single push**: include `[skip deck-build]` in the commit message of the push to `main`. The `if:` filter skips the run.
2. **Edit on a feature branch**: the workflow only watches `main`. Work on `feat/...`, render locally with `node scripts/render-workshop-decks.js`, open a manual PR with the rendered binaries — the workflow won't interfere. When you merge the PR, the workflow will run on the merge commit and re-render — but if your manual binaries match what the workflow produces, the diff is empty and no auto-PR is opened.

## How to debug a failed run

| Failure mode | Where to look | Fix |
|--------------|---------------|-----|
| Lint exit code 2 | Job log under "Render decks" | Fix the rule violation in `deck.md` and push again |
| Render exit code 3 | Job log under "Render decks" | Usually a Marp CLI / Chromium issue; re-run the workflow |
| Verify exit code 3 | Job log under "Verify decks" | Tooling issue (ImageMagick / LibreOffice missing); re-run |
| No PR opened despite changes | "Detect rendered file changes" step | Expected if `deck.md` change didn't alter rendered output (e.g., a comment edit) |
| Screenshots don't render in PR | View the auto-PR branch on github.com | Branch must be pushed before the PR body is built; if you see broken images, the workflow likely failed between push and PR-create — re-run |
| PR opened but with wrong tracks | "Detect affected tracks" step in the log | Path-filter mismatch; check that your deck.md follows the `<N>_<name>_deck.md` naming convention |

## Local reproduction

To run the same pipeline locally (matches CI exactly):

```bash
# Install tools
brew install imagemagick ghostscript
brew install --cask libreoffice

# Render
node scripts/render-workshop-decks.js --only T1 --verbose

# Verify (rasterize)
node scripts/verify-workshop-decks.js --only T1 --verbose

# Inspect
open .deck-screenshots/T1/pdf/slide-00.png
```

## Quality rules enforced

The render script pre-flight lints each deck against three quality rules:

- **L1** — Inline `<svg>` blocks are forbidden. Use external files at `workshops/shared/img/<name>.svg` referenced via `<img src="../shared/img/...">`.
- **L11** — Marp class directives (`<!-- _class: ... -->`) must live in their own comment block, separate from speaker-note comments.
- **L15** — Trailing `---` at end of file would create an empty extra slide. Remove it.

The full 15-rule catalogue (L1–L15) lives in the marp-deck playbook in the [content-creation repo](https://github.com/sendtoshailesh/content-creation/blob/main/docs/marp-deck-playbook-and-git-ape-marketing-followup.md). Three rules are enforced automatically (above); the remaining 12 are reviewer responsibility.

## Phase 2 — Agentic content regeneration (implemented)

Phase 1 (the deck-build workflow above) is **render only**: when source files
change, the deck *text* doesn't update — only the rendered binaries refresh.

Phase 2 closes that loop. It is implemented as the agentic workflow
**`.github/workflows/git-ape-workshop-content-updater.md`** (gh-aw; compiled to
`git-ape-workshop-content-updater.lock.yml`).

**Trigger.** Weekly schedule (`weekly on monday`, fuzzed by gh-aw) plus
`workflow_dispatch` with an optional `focus` input. Rather than reacting to a
single push, it periodically assesses *the whole gap* between the repository's
current features and the existing workshop content.

**Grounding.** A deterministic pre-step (outside the agent sandbox) builds an
authoritative `.workshop-snapshots/WORKSHOP-INVENTORY.md`: every agent, skill, and
core workflow with its last-change date and a `grep`-based coverage count across
`workshops/**`, plus recently-changed feature files. The agent must read this
first, so it reasons from ground truth instead of guessing.

**What it does.**

1. Reads the inventory, open `workshop-sync` issues, and its own cache memory.
2. Classifies each gap: *new & uncovered*, *existing & changed*, or *in sync* —
   after a scope filter (e.g. it ignores the Azure-out-of-scope `aws-*` skills).
3. Infers the **user-centric persona/track** that benefits most from each feature.
4. Generates **section-level** content: revises affected labs/decks/glossary, adds
   new labs (and, rarely, new tracks), and updates the Docusaurus mirrors.

**Outputs (both human-reviewed; the agent never merges or deploys).**

- A rolling **`[workshop-coverage]` status issue** every run — the "what needs
  doing" assessment (coverage matrix, gaps, personas, work estimate). A distinct
  label/title-prefix keeps it separate from the deterministic `workshop-sync`
  issues.
- A **draft pull request** when content changes are warranted (label
  `workshop-sync`). It excludes rendered binaries (`*.pdf/pptx/html`) so the
  Phase-1 deck-build workflow re-renders them from the merged source. The PR adds
  `Closes #<n>` for any open `workshop-sync` issue it resolves.

**Guardrails.**

- Edits only `workshops/**` and `website/docs/workshops/**` — never `.github/`,
  source code, deck CSS front-matter, or rendered binaries.
- Never removes existing slides/labs; preserves each lab's stated timing and its
  no-Azure fallback path.
- Deck edits satisfy the same L1/L11/L15 lint the renderer enforces.
- Must verify every described command/output against the feature source — no
  fabricated behaviour.

**Relationship to the other workflows.** This workflow *augments* — it does not
replace — the deterministic `git-ape-workshop-sync.yml` (push-triggered issue
filer) and `git-ape-deck-build.yml` (deck renderer). Sync flags *what changed*,
the updater proposes *what the content should say*, and deck-build *renders* the
merged result.
