---
title: "Waza skill evals"
sidebar_label: "Waza skill evals"
description: "GitHub Actions workflow: Waza skill evals"
---

<!-- AUTO-GENERATED — DO NOT EDIT. Source: .github/workflows/waza-evals.yml -->


# Waza skill evals

**Workflow file:** `.github/workflows/waza-evals.yml`

## Triggers

- **`pull_request`** — paths: `.github/skills/**/SKILL.md, .github/skills/**/eval.yaml, .github/skills/**/tasks/**...`
- **`workflow_dispatch`**


## Permissions

- `contents: read`
- `pull-requests: write`

## Jobs

### `preflight`

| Property | Value |
|----------|-------|
| **Display Name** | Preflight (check secrets) |
| **Runs On** | `ubuntu-latest` |
| **Steps** | 1 |

### `prepare`

| Property | Value |
|----------|-------|
| **Display Name** | Determine matrix |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `preflight` |
| **Steps** | 2 |

### `tokens`

| Property | Value |
|----------|-------|
| **Display Name** | Token comparison vs main (advisory) |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `preflight` |
| **Steps** | 4 |

### `eval`

| Property | Value |
|----------|-------|
| **Display Name** | ${{ matrix.skill || 'eval' }} / ${{ matrix.model || 'skipped (no skill changes)' }} |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `preflight`, `prepare` |
| **Steps** | 7 |

### `comment`

| Property | Value |
|----------|-------|
| **Display Name** | Post advisory comment on PR |
| **Runs On** | `ubuntu-latest` |
| **Depends On** | `preflight`, `prepare`, `eval`, `tokens` |
| **Steps** | 3 |



## Source

<details>
<summary>Click to view full workflow YAML</summary>

```yaml
name: Waza skill evals

# Advisory-mode evaluation of agent skills.
# Runs on PRs that touch SKILL.md or any eval file. Posts a comment with results.
# Always non-blocking — eval failures never gate merges.
#
# Single source of truth: .github/evals/manifest.yaml
#   Lists configured skills, tier classification, and per-tier model fan-out.
#   Edit that file to add/remove a skill or promote a tier — this workflow
#   reads it dynamically and needs no changes.
#
# Architecture:
#   - `prepare` job: reads the manifest, then diffs base..head (or honors a
#     workflow_dispatch input) to determine which subset of skills to
#     evaluate. Builds the matrix.include payload (one entry per
#     skill × tier-model). Project-wide config changes (.waza.yaml, this
#     workflow file, the manifest) trigger the full matrix.
#   - `tokens` job: runs once, compares token counts across all skills vs main
#     and uploads the result for the comment job. Cheap, always runs.
#   - `eval` job: matrix expanded purely from `prepare.outputs.legs`. Each
#     leg runs the eval suite plus per-skill signal steps (tokens profile,
#     quality, check). Uploads per-leg artifacts. Skipped entirely if no
#     skills changed.
#   - `comment` job: fan-in. Downloads all artifacts and posts a single
#     `<!-- waza-evals-comment -->` PR comment with one section per skill
#     (in manifest order) plus a header noting which skills ran and why.
#
# Per-PR scoping:
#   - Skill-only changes → only changed skills run (saves Copilot quota).
#   - .waza.yaml, manifest, or workflow file changes → full matrix.
#   - .github/evals/<skill>/ changes → that skill only.
#   - workflow_dispatch with no input → full matrix.
#   - workflow_dispatch with `skill:` input → that skill only.
#
# Notes:
#   - waza's eval schema only supports `skill:`. Custom agents under
#     .github/agents/*.agent.md are *not* evaluable by this workflow. See
#     docs/WAZA.md "Agent evals" for the upstream limitation.
#   - copilot-sdk needs a Copilot-scoped token. Default GITHUB_TOKEN does
#     NOT carry that scope. We use the `COPILOT_GITHUB_TOKEN` repo secret.
#     Comment posting uses the default token (only needs pull-requests: write).

on:
  pull_request:
    paths:
      - '.github/skills/**/SKILL.md'
      - '.github/skills/**/eval.yaml'
      - '.github/skills/**/tasks/**'
      - '.github/skills/**/fixtures/**'
      - '.github/evals/**'
      - '.waza.yaml'
      - '.github/workflows/waza-evals.yml'
  workflow_dispatch:
    inputs:
      skill:
        description: 'Single skill name to run (default: all configured pilot evals)'
        required: false
        type: string

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: waza-evals-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

# Pin waza to a known-good release. Bump deliberately after validating that
# the new version's eval behavior still matches our baselines. Never resolve
# via `latest` — the microsoft/waza repo publishes the core release and the
# sibling azd-extension release at the same commit, and GitHub's
# `releases/latest` endpoint returns whichever was published last, which has
# bitten PR #109 with a 404 on the wrong asset.
env:
  WAZA_VERSION: 'v0.37.0'

# Note: there is no top-level skill list. The canonical list lives in
# .github/evals/manifest.yaml and is read by the `prepare` job below.

jobs:
  # ---------------------------------------------------------------------------
  # preflight: verify that the COPILOT_GITHUB_TOKEN secret is configured.
  # When absent, every downstream job is skipped cleanly (no red checks). The
  # maintainer setup steps are in PR #109 / README.
  # ---------------------------------------------------------------------------
  preflight:
    name: Preflight (check secrets)
    runs-on: ubuntu-latest
    timeout-minutes: 2
    outputs:
      enabled: ${{ steps.check.outputs.enabled }}
    steps:
      - name: Check COPILOT_GITHUB_TOKEN availability
        id: check
        env:
          TOKEN: ${{ secrets.COPILOT_GITHUB_TOKEN }}
        run: |
          if [ -z "${TOKEN:-}" ]; then
            echo "enabled=false" >> "$GITHUB_OUTPUT"
            echo "::notice::COPILOT_GITHUB_TOKEN secret is not set. Skipping all waza skill eval jobs. See repo README / PR #109 for setup."
            exit 0
          fi
          # Token is set — verify it can actually read the private microsoft/waza
          # repo (release downloads need access). Reject silently if 401/403/404.
          # Capture headers + body for diagnostics (no token is ever printed).
          hdr_file=$(mktemp)
          body_file=$(mktemp)
          http_code=$(curl -sS -D "${hdr_file}" -o "${body_file}" -w "%{http_code}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/microsoft/waza/releases/latest || true)
          if [ "${http_code}" = "200" ]; then
            echo "enabled=true" >> "$GITHUB_OUTPUT"
            echo "COPILOT_GITHUB_TOKEN can read microsoft/waza — eval jobs will run."
          else
            echo "enabled=false" >> "$GITHUB_OUTPUT"
            echo "::notice::COPILOT_GITHUB_TOKEN cannot read microsoft/waza (HTTP ${http_code}). Skipping all waza skill eval jobs."
            echo "--- diagnostic: response headers (token not included) ---"
            grep -iE '^(http|x-oauth-scopes|x-accepted-oauth-scopes|x-github-sso|x-ratelimit-remaining|x-ratelimit-used|x-github-request-id):' "${hdr_file}" || true
            echo "--- diagnostic: response body (first 500 bytes) ---"
            head -c 500 "${body_file}" || true
            echo
            echo "--- diagnostic: token-user identity probe ---"
            user_code=$(curl -sS -o "${body_file}.user" -w "%{http_code}" \
              -H "Authorization: Bearer ${TOKEN}" \
              -H "Accept: application/vnd.github+json" \
              https://api.github.com/user || true)
            echo "GET /user -> HTTP ${user_code}"
            if [ "${user_code}" = "200" ]; then
              # Print only the login + token type, never the token itself.
              jq -r '"token user: \(.login)  (type: \(.type))"' "${body_file}.user" 2>/dev/null || head -c 200 "${body_file}.user"
            else
              head -c 300 "${body_file}.user" || true
            fi
            echo
          fi
          rm -f "${hdr_file}" "${body_file}" "${body_file}.user"

  # ---------------------------------------------------------------------------
  # prepare: read .github/evals/manifest.yaml and decide which skills to
  # evaluate based on the diff / dispatch input. Outputs:
  #   - skills: JSON array of selected skill names (drives comment ordering)
  #   - legs:   JSON array of {skill, model, baseline} for matrix.include
  #   - baseline_models: JSON array of model names that run with --baseline
  #   - mode/reason: human-readable scope info for the PR comment banner
  # ---------------------------------------------------------------------------
  prepare:
    name: Determine matrix
    runs-on: ubuntu-latest
    timeout-minutes: 5
    needs: preflight
    if: needs.preflight.outputs.enabled == 'true'
    outputs:
      skills: ${{ steps.select.outputs.skills }}
      legs: ${{ steps.select.outputs.legs }}
      baseline_models: ${{ steps.select.outputs.baseline_models }}
      reason: ${{ steps.select.outputs.reason }}
      mode: ${{ steps.select.outputs.mode }}
    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Select skills
        id: select
        env:
          REQUESTED: ${{ inputs.skill }}
          EVENT: ${{ github.event_name }}
          BASE_SHA: ${{ github.event.pull_request.base.sha }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
        run: |
          set -euo pipefail

          # Source of truth for skills + tier + per-tier model fan-out.
          manifest=".github/evals/manifest.yaml"
          if [ ! -f "$manifest" ]; then
            echo "::error::manifest not found: $manifest"
            exit 1
          fi

          # Convert YAML -> JSON once; everything else is jq.
          manifest_json="$(yq -o=json '.' "$manifest")"

          ALL_SKILLS="$(echo "$manifest_json" | jq -c '[.skills[].name]')"
          BASELINE_MODELS="$(echo "$manifest_json" | jq -c '
            [ .tiers[].models[] | select(.baseline == true) | .name ] | unique
          ')"
          echo "ALL_SKILLS=$ALL_SKILLS"
          echo "BASELINE_MODELS=$BASELINE_MODELS"

          # emit <selected-skills-json> <mode> <human-reason>
          # Computes `legs` from selected skills + manifest tiers and writes
          # all four outputs (skills, legs, baseline_models, mode, reason).
          emit() {
            local selected="$1" mode="$2" reason="$3"
            local legs
            legs="$(echo "$manifest_json" | jq -c --argjson sel "$selected" '
              . as $root
              | [ $root.skills[]
                  | .name as $sname
                  | select($sel | index($sname))
                  | .tier as $tier
                  | $root.tiers[$tier].models[]
                  | { skill: $sname, model: .name, baseline: (.baseline == true) }
                ]
            ')"
            {
              echo "skills=${selected}"
              echo "legs=${legs}"
              echo "baseline_models=${BASELINE_MODELS}"
              echo "mode=${mode}"
              echo "reason=${reason}"
            } >> "$GITHUB_OUTPUT"
            echo "Selected skills: ${selected}"
            echo "Legs: ${legs}"
            echo "Mode: ${mode}"
            echo "Reason: ${reason}"
          }

          # --- Case 1: workflow_dispatch with single-skill input ---
          if [ "$EVENT" = "workflow_dispatch" ] && [ -n "${REQUESTED:-}" ]; then
            if echo "$ALL_SKILLS" | jq -e --arg s "$REQUESTED" '. | index($s)' > /dev/null; then
              emit "[\"$REQUESTED\"]" "single" "workflow_dispatch input ($REQUESTED)"
              exit 0
            else
              echo "::error::Requested skill '$REQUESTED' is not in the manifest ($ALL_SKILLS)"
              exit 1
            fi
          fi

          # --- Case 2: workflow_dispatch without input → full matrix ---
          if [ "$EVENT" = "workflow_dispatch" ]; then
            emit "$ALL_SKILLS" "full" "workflow_dispatch (no input → full matrix)"
            exit 0
          fi

          # --- Case 3: pull_request — diff against base ---
          if [ -z "${BASE_SHA:-}" ] || [ -z "${HEAD_SHA:-}" ]; then
            emit "$ALL_SKILLS" "full" "pull_request: missing base/head SHA → full matrix"
            exit 0
          fi

          # Make sure the base commit is fetched (checkout fetched everything
          # via fetch-depth: 0, but be defensive in case of shallow merges).
          git fetch --no-tags origin "$BASE_SHA" 2>/dev/null || true

          changed=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA" || true)
          if [ -z "$changed" ]; then
            emit "[]" "none" "no files changed in PR"
            exit 0
          fi

          echo "--- changed files ---"
          echo "$changed"
          echo "---------------------"

          # Project-wide config changes → full matrix.
          # Includes the manifest itself: changing tiers / model fan-out
          # affects every skill, so re-run everything.
          if echo "$changed" | grep -qE '^(\.waza\.yaml|\.github/workflows/waza-evals\.yml|\.github/evals/manifest\.yaml)$'; then
            emit "$ALL_SKILLS" "full" "project-wide config change (.waza.yaml, manifest, or workflow file) → full matrix"
            exit 0
          fi

          # Per-skill changes: collect skill names from both layouts.
          #   .github/skills/<name>/...   → SKILL.md, references, etc.
          #   .github/evals/<name>/...    → eval.yaml, tasks, fixtures.
          # NF >= 4 filter excludes files at the root of evals/ (like
          # manifest.yaml) which are handled by the config-wide check above.
          changed_skills=$(
            echo "$changed" | awk -F/ '
              /^\.github\/skills\// && NF >= 4 {print $3}
              /^\.github\/evals\//  && NF >= 4 {print $3}
            ' | sort -u
          )

          if [ -z "$changed_skills" ]; then
            emit "[]" "none" "no per-skill files changed"
            exit 0
          fi

          # Intersect with the canonical configured list.
          selected=$(
            printf '%s\n' "$changed_skills" \
              | jq -R -s -c --argjson all "$ALL_SKILLS" \
                  '[ split("\n")[] | select(length > 0) | select(IN($all[])) ]'
          )

          if [ "$selected" = "[]" ]; then
            emit "[]" "none" "changed skill(s) not in the manifest: $(echo "$changed_skills" | tr '\n' ' ')"
            exit 0
          fi

          count=$(echo "$selected" | jq 'length')
          names=$(echo "$selected" | jq -r 'join(", ")')
          emit "$selected" "subset" "diff-scoped: ${count} changed skill(s) — ${names}"

  # ---------------------------------------------------------------------------
  # tokens: compare token counts across all SKILL.md files vs main.
  # Runs once (not per-matrix) and uploads a single JSON artifact consumed
  # by the comment job. Advisory — never fails the workflow.
  # ---------------------------------------------------------------------------
  tokens:
    name: Token comparison vs main (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: preflight
    if: needs.preflight.outputs.enabled == 'true'
    continue-on-error: true
    env:
      GITHUB_TOKEN: ${{ secrets.COPILOT_GITHUB_TOKEN }}
      WAZA_NO_UPDATE_CHECK: '1'

    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Install waza (pinned release)
        run: |
          set -euo pipefail
          waza_version="${WAZA_VERSION}"
          if [ -z "${waza_version}" ]; then
            echo "::error::WAZA_VERSION env var is not set"
            exit 1
          fi
          echo "Installing waza ${waza_version}"

          os="$(uname -s | tr '[:upper:]' '[:lower:]')"
          arch="$(uname -m)"
          case "${arch}" in
            x86_64|amd64) arch=amd64 ;;
            aarch64|arm64) arch=arm64 ;;
          esac
          asset="waza-${os}-${arch}"
          base="https://github.com/microsoft/waza/releases/download/${waza_version}"
          tmp="$(mktemp -d)"

          curl -fsSL -o "${tmp}/${asset}"      "${base}/${asset}"
          curl -fsSL -o "${tmp}/checksums.txt" "${base}/checksums.txt"
          ( cd "${tmp}" && grep " ${asset}$" checksums.txt | sha256sum -c - )
          sudo install -m 0755 "${tmp}/${asset}" /usr/local/bin/waza
          rm -rf "${tmp}"
          waza --version

      - name: Token comparison vs main (advisory)
        id: tokens-compare
        run: |
          set -uo pipefail
          mkdir -p .waza-results
          # Advisory: no --strict so the step never fails the workflow.
          # --format json produces machine-readable output for the comment job.
          waza tokens compare main --skills --threshold 10 --format json \
            > .waza-results/tokens-compare.json 2>&1 || true
          echo "--- token comparison output ---"
          cat .waza-results/tokens-compare.json || true
          # Always exit cleanly — advisory only.
          exit 0

      - name: Upload token comparison artifact
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: waza-tokens-compare
          path: .waza-results/tokens-compare.json
          retention-days: 14
          if-no-files-found: warn
          include-hidden-files: true

  # ---------------------------------------------------------------------------
  # eval: matrix (skill x model). Each leg runs the eval suite plus per-skill
  # signal steps (tokens profile, quality, check). All steps are advisory.
  #
  # The skill axis is supplied by the `prepare` job — only changed skills run
  # on per-PR events; the full list runs on workflow_dispatch (no input) and
  # on PRs that touch project-wide config.
  # ---------------------------------------------------------------------------
  eval:
    name: "${{ matrix.skill || 'eval' }} / ${{ matrix.model || 'skipped (no skill changes)' }}"
    needs: [preflight, prepare]
    if: needs.preflight.outputs.enabled == 'true' && needs.prepare.outputs.legs != '[]' && needs.prepare.outputs.legs != ''
    runs-on: ubuntu-latest
    timeout-minutes: 25
    # Per-job continue-on-error so a single matrix leg failure doesn't fail
    # the whole workflow. Combined with `if: always()` on the comment job,
    # this guarantees the PR comment is posted even when some legs fail.
    continue-on-error: true
    strategy:
      fail-fast: false
      matrix:
        # Matrix is sourced entirely from the manifest via the prepare job.
        # Each include entry is `{ skill, model, baseline }`. Adding a skill
        # or promoting a tier means editing .github/evals/manifest.yaml —
        # never this workflow.
        include: ${{ fromJSON(needs.prepare.outputs.legs) }}
    env:
      # copilot-sdk authenticates with this token. Default GITHUB_TOKEN does
      # not carry Copilot scope, so we use a dedicated PAT in repo secrets.
      # Also reused for the release-API lookup (only needs public-repo read).
      GITHUB_TOKEN: ${{ secrets.COPILOT_GITHUB_TOKEN }}
      WAZA_NO_UPDATE_CHECK: '1'

    steps:
      - name: Checkout
        uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Install waza (pinned release)
        run: |
          set -euo pipefail
          waza_version="${WAZA_VERSION}"
          if [ -z "${waza_version}" ]; then
            echo "::error::WAZA_VERSION env var is not set"
            exit 1
          fi
          echo "Installing waza ${waza_version}"

          os="$(uname -s | tr '[:upper:]' '[:lower:]')"
          arch="$(uname -m)"
          case "${arch}" in
            x86_64|amd64) arch=amd64 ;;
            aarch64|arm64) arch=arm64 ;;
          esac
          asset="waza-${os}-${arch}"
          base="https://github.com/microsoft/waza/releases/download/${waza_version}"
          tmp="$(mktemp -d)"

          curl -fsSL -o "${tmp}/${asset}"      "${base}/${asset}"
          curl -fsSL -o "${tmp}/checksums.txt" "${base}/checksums.txt"
          ( cd "${tmp}" && grep " ${asset}$" checksums.txt | sha256sum -c - )
          sudo install -m 0755 "${tmp}/${asset}" /usr/local/bin/waza
          rm -rf "${tmp}"
          waza --version

      - name: Run waza eval (advisory)
        id: run
        run: |
          # GitHub's default shell is `bash -e`. `set -uo pipefail` does NOT
          # disable -e, so a non-zero exit from `waza run` (e.g. metric below
          # threshold) kills the script before `rc=$?` runs. Explicitly
          # disable errexit so we can capture the code and surface it in the
          # PR comment instead of failing the leg silently.
          set +e
          set -uo pipefail
          mkdir -p .waza-results
          spec=".github/evals/${{ matrix.skill }}/eval.yaml"
          # Slug used for filenames + artifact suffix; harmless when the
          # model has dots (gpt-5.4) since GH Actions allows them.
          slug="${{ matrix.skill }}-${{ matrix.model }}"

          # gpt-5.4 (and any other model flagged `baseline: true` in the
          # manifest) runs in --baseline (A/B) mode to cap quota cost while
          # still providing a reference point for cross-model comparison. All
          # other models run standard. The PR comment labels each leg.
          extra_flags=""
          if [ "${{ matrix.baseline }}" = "true" ]; then
            extra_flags="--baseline"
          fi

          # ---- Retry-on-session-not-found wrapper -----------------------------
          # The Copilot SDK occasionally drops the agent's session before
          # waza's `prompt` grader can resume it (`continue_session: true`),
          # producing JSON-RPC -32603 "Session not found" errors. When this
          # fires, the run is marked status=error with `validations: null` —
          # ALL graders' verdicts for that task are wiped, dragging the leg
          # aggregate down ~50–80% even when the agent's actual response was
          # correct.
          #
          # The error is purely transient (server-side session GC). Retrying
          # the leg with a fresh waza process consistently recovers. We retry
          # up to 2 times (3 total attempts) on session-not-found ONLY — other
          # errors (rate-limit 429, below-threshold scores, network) are NOT
          # retried since they have different recovery characteristics.
          #
          # Stdout (--format github-comment) is the markdown for the PR
          # comment; capture it cleanly to its own file. Stderr (progress,
          # task results, "Running benchmark:") streams to the runner log.
          # --model overrides the spec's config.model so we can fan out the
          # same eval suite across multiple models.
          #
          # --judge-model decouples the LLM-as-judge from the executor model
          # and pins it to claude-opus-4.7 for TWO reasons:
          #   1. No self-grading bias — opus-4.7 is NOT in any matrix tier
          #      (pilot: sonnet-4.6, gpt-5.4, gpt-5-codex, opus-4.6;
          #      expanded: sonnet-4.6, gpt-5-codex), so no runner leg is
          #      ever judged by its own model.
          #   2. Judge capability ≥ every runner — opus-4.7 is chosen as a
          #      higher-capability judge than the runner mix to reduce
          #      ceiling effects when scoring the strongest runners.
          # If a future tier ever adds opus-4.7 as a runner, the judge must
          # be re-pinned to a model that is still outside the new roster.
          #
          # --suggest --recommend appends outcome-tied recommendations.
          max_attempts=3
          attempt=0
          rc=0
          while [ $attempt -lt $max_attempts ]; do
            attempt=$((attempt + 1))
            echo "::group::waza run attempt ${attempt}/${max_attempts} for ${slug}"
            rc=0
            # shellcheck disable=SC2086
            waza run "${spec}" \
              --model "${{ matrix.model }}" \
              --judge-model "claude-opus-4.7" \
              --suggest \
              --recommend \
              ${extra_flags} \
              --format "github-comment" \
              --output ".waza-results/${slug}.json" \
              --reporter "junit:.waza-results/${slug}.junit.xml" \
              --parallel \
              > ".waza-results/${slug}.md"
            rc=$?
            echo "::endgroup::"

            if [ ! -f ".waza-results/${slug}.json" ]; then
              echo "::warning::attempt ${attempt}: no JSON produced (rc=${rc})"
              if [ $attempt -lt $max_attempts ]; then sleep 5; continue; fi
              break
            fi

            session_errs=$(jq -r '
              [.tasks[]?.runs[]? | select(.error_msg // "" | contains("Session not found"))] | length
            ' ".waza-results/${slug}.json" 2>/dev/null || echo 0)

            if [ "${session_errs}" = "0" ]; then
              echo "::notice::${slug} attempt ${attempt} clean (no session-not-found errors)"
              break
            fi

            echo "::warning::${slug} attempt ${attempt} hit ${session_errs} session-not-found error(s)"
            if [ $attempt -lt $max_attempts ]; then
              # Discard partial artifacts so the next attempt is independent.
              rm -f ".waza-results/${slug}.json" ".waza-results/${slug}.md" ".waza-results/${slug}.junit.xml"
              sleep 5
            fi
          done
          # If retries exhausted and the artifact STILL has session-not-found
          # errors, the data is corrupt (validations: null on affected runs
          # would drag the leg aggregate down 50–80% as a fake "low score").
          # Discard it so the PR comment surfaces this as INFRA_FAILED rather
          # than a misleading low score.
          final_session_errs=0
          if [ -f ".waza-results/${slug}.json" ]; then
            final_session_errs=$(jq -r '
              [.tasks[]?.runs[]? | select(.error_msg // "" | contains("Session not found"))] | length
            ' ".waza-results/${slug}.json" 2>/dev/null || echo 0)
          fi
          if [ "${final_session_errs}" != "0" ]; then
            echo "::error::${slug} still has ${final_session_errs} session-not-found error(s) after ${max_attempts} attempts — discarding corrupt artifact"
            printf 'session_not_found_errors=%s\nattempts=%s\nlast_exit_code=%s\n' \
              "${final_session_errs}" "${max_attempts}" "${rc}" \
              > ".waza-results/${slug}.infra-failed"
            rm -f ".waza-results/${slug}.json" ".waza-results/${slug}.junit.xml"
            # Replace the markdown summary with a clear INFRA_FAILED notice
            # so the PR comment shows the actual problem instead of stale
            # markdown from one of the failed attempts. Use printf (no heredoc)
            # because heredoc EOF terminators clash with YAML block-scalar
            # indentation rules in `run: |` steps.
            {
              printf '### `%s` — INFRA_FAILED\n\n' "${slug}"
              printf 'waza run hit `%s` `Session not found` JSON-RPC error(s) ' "${final_session_errs}"
              printf 'from the Copilot SDK after **%s attempt(s)**. ' "${max_attempts}"
              printf 'The session-resume path used by `prompt` graders with '
              printf '`continue_session: true` is intermittently flaky in CI; '
              printf 'retries did not recover. **No score is reported for this leg** '
              printf '— treating a corrupted run as a low score would be misleading.\n'
            } > ".waza-results/${slug}.md"
          fi
          # ---- end retry wrapper ----------------------------------------------

          echo "exit_code=${rc}" >> "$GITHUB_OUTPUT"
          echo
          echo "--- captured PR-comment markdown ---"
          cat ".waza-results/${slug}.md" || true
          # Never fail the step itself — surface the code in the comment.
          exit 0

      - name: Tokens profile (advisory)
        id: tokens-profile
        continue-on-error: true
        run: |
          set -uo pipefail
          slug="${{ matrix.skill }}-${{ matrix.model }}"
          mkdir -p .waza-results
          waza tokens profile ".github/skills/${{ matrix.skill }}" \
            > ".waza-results/${slug}-tokens-profile.txt" 2>&1 || true
          cat ".waza-results/${slug}-tokens-profile.txt" || true
          exit 0

      - name: Quality signal (advisory)
        id: quality
        continue-on-error: true
        run: |
          set -uo pipefail
          slug="${{ matrix.skill }}-${{ matrix.model }}"
          mkdir -p .waza-results
          # --judge-model omitted: this step uses the project default judge model
          # (claude-sonnet-4.6 from .waza.yaml) for consistent quality scoring
          # regardless of which executor model is running in this matrix leg.
          waza quality ".github/skills/${{ matrix.skill }}" --format table \
            > ".waza-results/${slug}-quality.txt" 2>&1 || true
          cat ".waza-results/${slug}-quality.txt" || true
          exit 0

      - name: Compliance check (advisory)
        id: check
        continue-on-error: true
        run: |
          set -uo pipefail
          slug="${{ matrix.skill }}-${{ matrix.model }}"
          mkdir -p .waza-results
          waza check ".github/skills/${{ matrix.skill }}" \
            > ".waza-results/${slug}-check.txt" 2>&1 || true
          cat ".waza-results/${slug}-check.txt" || true
          exit 0

      - name: Upload eval artifacts
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: waza-results-${{ matrix.skill }}-${{ matrix.model }}
          path: .waza-results/
          retention-days: 14
          if-no-files-found: warn
          # `.waza-results/` starts with a dot, and upload-artifact treats
          # any path segment starting with `.` as hidden by default. Without
          # this, the artifact is silently empty.
          include-hidden-files: true

  # ---------------------------------------------------------------------------
  # comment: fan-in. Downloads all artifacts and posts one aggregated comment.
  # ---------------------------------------------------------------------------
  comment:
    name: Post advisory comment on PR
    needs: [preflight, prepare, eval, tokens]
    if: github.event_name == 'pull_request' && needs.preflight.outputs.enabled == 'true' && always()
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - name: Download all eval artifacts
        uses: actions/download-artifact@v8
        with:
          path: artifacts
          pattern: waza-results-*
          merge-multiple: false

      - name: Download token comparison artifact
        uses: actions/download-artifact@v8
        with:
          name: waza-tokens-compare
          path: artifacts/waza-tokens-compare
        continue-on-error: true

      - name: Aggregate and post comment
        uses: actions/github-script@v9
        env:
          PREPARE_MODE: ${{ needs.prepare.outputs.mode }}
          PREPARE_REASON: ${{ needs.prepare.outputs.reason }}
          PREPARE_SKILLS: ${{ needs.prepare.outputs.skills }}
          PREPARE_BASELINES: ${{ needs.prepare.outputs.baseline_models }}
        with:
          # Default GITHUB_TOKEN — has `pull-requests: write` and is the
          # right identity for bot-style comments.
          github-token: ${{ secrets.GITHUB_TOKEN }}
          script: |
            const fs = require('fs');
            const path = require('path');

            // Each matrix job uploads `waza-results-<skill>-<model>`
            // containing per-leg files (slug.md, slug-tokens-profile.txt,
            // slug-quality.txt, slug-check.txt).
            //
            // Skill ordering and baseline-model classification are sourced
            // from .github/evals/manifest.yaml via the prepare job — no
            // hardcoded lists in this workflow.
            const skills = JSON.parse(process.env.PREPARE_SKILLS || '[]');
            const baselineModels = new Set(
              JSON.parse(process.env.PREPARE_BASELINES || '[]')
            );
            const root = 'artifacts';
            const allDirs = fs.existsSync(root)
              ? fs.readdirSync(root)
                  .filter((d) => d.startsWith('waza-results-'))
                  .sort()
              : [];

            // Helper: read a file, return trimmed content or fallback string.
            // Logs a debug note when returning the fallback so missing artifacts
            // are visible in the Actions log without failing the step.
            function readArtifact(filePath, fallback) {
              if (fs.existsSync(filePath)) {
                const c = fs.readFileSync(filePath, 'utf8').trim();
                if (c) return c;
                core.debug(`readArtifact: file exists but is empty — ${filePath}`);
              } else {
                core.debug(`readArtifact: file not found — ${filePath}`);
              }
              return fallback;
            }

            // Helper: wrap content in a <details> block if it exceeds threshold.
            function maybeCollapse(summary, content, threshold) {
              const limit = threshold || 50;
              const lines = content.split('\n').length;
              if (lines > limit) {
                return `<details><summary>${summary} (${lines} lines — click to expand)</summary>\n\n${content}\n\n</details>`;
              }
              return `**${summary}**\n\n${content}`;
            }

            // Group artifacts by skill.
            const bySkill = new Map();
            for (const d of allDirs) {
              const rest = d.replace(/^waza-results-/, '');
              const skill = skills.find((s) => rest === s || rest.startsWith(s + '-'));
              if (!skill) continue;
              const model = rest === skill ? '(default)' : rest.slice(skill.length + 1);
              if (!bySkill.has(skill)) bySkill.set(skill, []);
              bySkill.get(skill).push({ model, dir: d, slug: rest });
            }

            // Token comparison section (top-level, from tokens job).
            let tokenCompareSection = '';
            const tcPath = path.join(root, 'waza-tokens-compare', 'tokens-compare.json');
            const tcRaw = readArtifact(tcPath, '');
            if (tcRaw) {
              const tcBlock = '```json\n' + tcRaw + '\n```';
              tokenCompareSection = [
                '<details><summary>📊 Token comparison vs <code>main</code> (advisory)</summary>',
                '',
                tcBlock,
                '',
                '</details>',
                '',
              ].join('\n');
            }

            // Build per-skill sections.
            const sections = [];
            for (const skill of skills) {
              if (!bySkill.has(skill)) continue;
              const legs = bySkill.get(skill).sort((a, b) => a.model.localeCompare(b.model));

              // Score (per model) + Suggestions/Recommendations
              const scoreParts = [];
              for (const leg of legs) {
                const isBaseline = baselineModels.has(leg.model);
                const modelLabel = isBaseline
                  ? leg.model + ' *(baseline — A/B mode)*'
                  : leg.model;
                const mdPath = path.join(root, leg.dir, leg.slug + '.md');
                const body = readArtifact(mdPath,
                  '_No output captured. See workflow logs and the `' + leg.dir + '` artifact._');
                scoreParts.push('<details><summary>Model: <code>' + modelLabel +
                  '</code></summary>\n\n' + body + '\n\n</details>');
              }
              const scoreSection = '<details><summary>📈 Score (per model) + Suggestions/Recommendations</summary>\n\n' +
                scoreParts.join('\n\n') + '\n\n</details>';

              // Tokens (count + profile) — model-independent, use first available leg.
              let tokenBody = '_Not available._';
              for (const leg of legs) {
                const tp = path.join(root, leg.dir, leg.slug + '-tokens-profile.txt');
                const c = readArtifact(tp, '');
                if (c) { tokenBody = '```\n' + c + '\n```'; break; }
              }
              const tokenSection = maybeCollapse('🔢 Tokens (count + profile)', tokenBody);

              // Quality (5-dim table) — model-independent, use first available leg.
              let qualityBody = '_Not available._';
              for (const leg of legs) {
                const qp = path.join(root, leg.dir, leg.slug + '-quality.txt');
                const c = readArtifact(qp, '');
                if (c) { qualityBody = '```\n' + c + '\n```'; break; }
              }
              const qualitySection = maybeCollapse('🎯 Quality (5-dim table)', qualityBody);

              // Check (compliance summary) — model-independent, use first available leg.
              let checkBody = '_Not available._';
              for (const leg of legs) {
                const cp = path.join(root, leg.dir, leg.slug + '-check.txt');
                const c = readArtifact(cp, '');
                if (c) { checkBody = '```\n' + c + '\n```'; break; }
              }
              // `waza check` expects `eval.yaml` colocated with `SKILL.md`. This
              // repo separates them (`.github/skills/<name>/SKILL.md` vs
              // `.github/evals/<name>/eval.yaml`), so the "Evaluation Suite:
              // Not Found" line is a false negative — the eval actually ran
              // (see the "Score" section above). Prepend a note so reviewers
              // are not misled.
              const checkNote =
                '> ℹ️ **`waza check` expects `eval.yaml` colocated with `SKILL.md`.** ' +
                'This repo separates them into `.github/evals/' + skill + '/eval.yaml`, ' +
                'so the "Evaluation Suite: Not Found" line below is a false negative — ' +
                'the eval actually ran (see the **Score** section above).\n\n';
              const checkSection = maybeCollapse('✅ Check (compliance summary)', checkNote + checkBody);

              sections.push([
                '### Skill: `' + skill + '`',
                '',
                scoreSection,
                '',
                tokenSection,
                '',
                qualitySection,
                '',
                checkSection,
              ].join('\n'));
            }

            const totalLegs = allDirs.length;

            // Selection-mode banner from the prepare job.
            const prepareMode = (process.env.PREPARE_MODE || '').trim();
            const prepareReason = (process.env.PREPARE_REASON || '').trim();
            let scopeBanner = '';
            if (prepareMode === 'none') {
              scopeBanner =
                '> ℹ️ **No skills evaluated.** ' + (prepareReason || 'No relevant changes detected.') +
                ' The token comparison above (if any) is the only signal for this PR.';
            } else if (prepareMode === 'subset') {
              scopeBanner =
                '> 🎯 **Diff-scoped run.** ' + (prepareReason || 'Only changed skills evaluated.') +
                ' Touch `.waza.yaml` or trigger `workflow_dispatch` to run the full matrix.';
            } else if (prepareMode === 'single') {
              scopeBanner =
                '> 🎯 **Single-skill run.** ' + (prepareReason || 'workflow_dispatch input.');
            } else if (prepareMode === 'full') {
              scopeBanner =
                '> 🔁 **Full matrix run.** ' + (prepareReason || 'All configured skills evaluated.');
            }

            const header = [
              '<!-- waza-evals-comment -->',
              '## 🧪 Waza skill evals (advisory)',
              '',
              scopeBanner,
              scopeBanner ? '' : null,
              'Ran ' + totalLegs + ' matrix leg' + (totalLegs === 1 ? '' : 's') +
                ' in parallel (skills × models). Results are non-blocking — investigate failures via the workflow logs and the per-leg `waza-results-*` artifacts.',
              '',
              '> **Legend:** Models flagged `baseline: true` in `.github/evals/manifest.yaml` (currently: `' +
                (Array.from(baselineModels).join('`, `') || 'none') +
                '`) run with `--baseline` (A/B mode) to cap quota. All other models run standard. Judge model is fixed at `claude-opus-4.7` across all legs.',
              '',
            ].filter((line) => line !== null).join('\n');

            // Assemble body. Each major block is separated by a blank line so
            // that GitHub Flavored Markdown correctly recognizes the per-skill
            // `### Skill: ...` headings (without a blank line after the
            // preceding `</details>` they get rendered as plain text).
            const sectionsBlock = sections.length > 0
              ? sections.join('\n\n---\n\n')
              : '_No artifacts produced. See workflow logs._';
            const body = [
              header.replace(/\s+$/, ''),
              tokenCompareSection.replace(/\s+$/, ''),
              sectionsBlock,
            ].filter((s) => s.length > 0).join('\n\n') + '\n';

            const { owner, repo } = context.repo;
            const issue_number = context.payload.pull_request.number;

            // Paginate to find our marker comment — listComments defaults to
            // 30 per page and our comment may be beyond that on busy PRs.
            let existing = null;
            for await (const response of github.paginate.iterator(
              github.rest.issues.listComments,
              { owner, repo, issue_number, per_page: 100 }
            )) {
              const found = response.data.find((c) => c.body && c.body.includes('<!-- waza-evals-comment -->'));
              if (found) { existing = found; break; }
            }

            if (existing) {
              await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
            } else {
              await github.rest.issues.createComment({ owner, repo, issue_number, body });
            }

```

</details>
