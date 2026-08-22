#!/usr/bin/env bash
# Sync mirror between canonical onboarding templates and the repository's
# active .github/copilot-instructions.md.
#
# Canonical source:
#   .github/skills/git-ape-onboarding/templates/
#
# Mirror destinations:
#   .github/copilot-instructions.md
#
# Note: The workflow templates under templates/workflows/ are NOT mirrored
# into this repository's .github/workflows/. They are scaffolded only into a
# USER's repository by scripts/scaffold-repo.{sh,ps1} during onboarding.
#
# Usage (run from any directory inside the repo):
#   .github/skills/git-ape-onboarding/scripts/sync-templates.sh check   # exit 1 on drift (CI gate)
#   .github/skills/git-ape-onboarding/scripts/sync-templates.sh apply   # copy templates -> mirrors
#   .github/skills/git-ape-onboarding/scripts/sync-templates.sh diff    # show per-file diffs
#
# The canonical templates ship inside the VS Code extension folder. The
# matching repo-root copies must stay byte-identical so this repository's own
# Copilot agent uses the same deployment standards it distributes to users.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TEMPLATES_DIR="$REPO_ROOT/.github/skills/git-ape-onboarding/templates"

# Mapping: template-relative-path -> repo-relative-destination
declare -a MAPPINGS=(
  "copilot-instructions.md:.github/copilot-instructions.md"
)

# Color output when stdout is a TTY.
if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
fi

usage() {
  cat <<EOF
Usage: $0 <check|apply|diff>

  check   Exit 1 if any mirror differs from its canonical template.
          Used by CI (.github/workflows/git-ape-onboarding-template-check.yml).

  apply   Overwrite each mirror with its canonical template. Run this after
          editing a template, then commit both the template and the mirror.

  diff    Show a unified diff for every divergent pair. Exits 0 regardless.
EOF
}

cmd="${1:-}"
case "$cmd" in
  check|apply|diff) ;;
  ""|-h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

drift=0
applied=0
checked=0

for mapping in "${MAPPINGS[@]}"; do
  src_rel="${mapping%%:*}"
  dst_rel="${mapping#*:}"
  src="$TEMPLATES_DIR/$src_rel"
  dst="$REPO_ROOT/$dst_rel"
  checked=$((checked + 1))

  if [[ ! -f "$src" ]]; then
    printf '%sERROR%s missing canonical template: %s\n' "$RED" "$RESET" "$src_rel" >&2
    exit 2
  fi

  case "$cmd" in
    apply)
      if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        printf '%s=%s %s (already in sync)\n' "$YELLOW" "$RESET" "$dst_rel"
      else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        printf '%s✓%s %s (updated from template)\n' "$GREEN" "$RESET" "$dst_rel"
        applied=$((applied + 1))
      fi
      ;;
    check)
      if [[ ! -f "$dst" ]]; then
        printf '%s✗%s %s (mirror missing)\n' "$RED" "$RESET" "$dst_rel" >&2
        drift=$((drift + 1))
      elif ! cmp -s "$src" "$dst"; then
        printf '%s✗%s %s (drift from template)\n' "$RED" "$RESET" "$dst_rel" >&2
        drift=$((drift + 1))
      else
        printf '%s✓%s %s\n' "$GREEN" "$RESET" "$dst_rel"
      fi
      ;;
    diff)
      if [[ ! -f "$dst" ]]; then
        printf '%s✗%s %s (missing)\n' "$RED" "$RESET" "$dst_rel"
        drift=$((drift + 1))
      elif ! cmp -s "$src" "$dst"; then
        printf '%s---%s diff: %s vs %s\n' "$BOLD" "$RESET" \
          ".github/skills/git-ape-onboarding/templates/$src_rel" "$dst_rel"
        diff -u "$src" "$dst" || true
        drift=$((drift + 1))
      fi
      ;;
  esac
done

case "$cmd" in
  apply)
    if [[ "$applied" -eq 0 ]]; then
      printf '\n%sAll %d mirror(s) already in sync.%s\n' "$GREEN" "$checked" "$RESET"
    else
      printf '\n%sUpdated %d mirror file(s).%s Commit them with the template changes.\n' \
        "$GREEN" "$applied" "$RESET"
    fi
    ;;
  check)
    if [[ "$drift" -gt 0 ]]; then
      printf '\n%s%d file(s) out of sync.%s Run:\n  .github/skills/git-ape-onboarding/scripts/sync-templates.sh apply\nand commit the updated mirror(s).\n' \
        "$RED" "$drift" "$RESET" >&2
      exit 1
    fi
    printf '\n%sAll %d mirror(s) match the canonical templates.%s\n' "$GREEN" "$checked" "$RESET"
    ;;
  diff)
    if [[ "$drift" -eq 0 ]]; then
      printf '\n%sNo divergence detected.%s\n' "$GREEN" "$RESET"
    fi
    ;;
esac
