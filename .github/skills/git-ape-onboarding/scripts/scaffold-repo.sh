#!/usr/bin/env bash
# Scaffold Git-Ape workflow files and deployment standards into a target repo.
#
# Usage:
#   .github/skills/git-ape-onboarding/scripts/scaffold-repo.sh [target_repo_root]
#
# Default target_repo_root: `git rev-parse --show-toplevel`, or the current
# working directory if not inside a git repo.
#
# Behavior:
# - Creates target_repo_root/.github/workflows/ if missing
# - Copies each template to its destination ONLY if destination does not exist
# - Prints "✓ Created" for new files, "⊝ Skipped" for collisions
# - Final line summarizes counts; lists skipped files at the end so the user
#   can reconcile them manually
# - NEVER runs git add / commit / push / PR — the resulting files are left
#   unstaged in the working copy
#
# Exit codes:
#   0 - success (some files may have been skipped)
#   1 - usage error or unrecoverable failure (e.g. template missing)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$SKILL_DIR/templates"

TARGET_ROOT="${1:-$(git -C . rev-parse --show-toplevel 2>/dev/null || pwd)}"

if [ ! -d "$TEMPLATES_DIR" ]; then
  echo "ERROR: templates directory not found at $TEMPLATES_DIR" >&2
  exit 1
fi

if [ ! -d "$TARGET_ROOT" ]; then
  echo "ERROR: target repo root not found: $TARGET_ROOT" >&2
  exit 1
fi

# src (relative to templates dir) : dst (relative to target_repo_root)
MAPPINGS=(
  "workflows/git-ape-plan.yml:.github/workflows/git-ape-plan.yml"
  "workflows/git-ape-deploy.yml:.github/workflows/git-ape-deploy.yml"
  "workflows/git-ape-destroy.yml:.github/workflows/git-ape-destroy.yml"
  "workflows/git-ape-verify.yml:.github/workflows/git-ape-verify.yml"
  "workflows/git-ape-drift.md:.github/workflows/git-ape-drift.md"
  "workflows/git-ape-drift.lock.yml:.github/workflows/git-ape-drift.lock.yml"
  "copilot-instructions.md:.github/copilot-instructions.md"
)

if [ -t 1 ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

printf '%sScaffolding Git-Ape files into:%s %s\n\n' "$BOLD" "$RESET" "$TARGET_ROOT"

created=0
skipped=0
skipped_paths=()

for mapping in "${MAPPINGS[@]}"; do
  src="${mapping%%:*}"
  dst="${mapping#*:}"
  src_path="$TEMPLATES_DIR/$src"
  dst_path="$TARGET_ROOT/$dst"

  if [ ! -f "$src_path" ]; then
    echo "ERROR: template missing: $src_path" >&2
    exit 1
  fi

  if [ -e "$dst_path" ]; then
    printf '  %s⊝ Skipped%s  %s (already exists)\n' "$YELLOW" "$RESET" "$dst"
    skipped=$((skipped + 1))
    skipped_paths+=("$dst")
  else
    mkdir -p "$(dirname "$dst_path")"
    cp "$src_path" "$dst_path"
    printf '  %s✓ Created%s  %s\n' "$GREEN" "$RESET" "$dst"
    created=$((created + 1))
  fi
done

printf '\n%sCreated %d file(s), skipped %d file(s).%s\n' \
  "$BOLD" "$created" "$skipped" "$RESET"

if [ "$skipped" -gt 0 ]; then
  printf '\nSkipped files were left unchanged. Diff against the canonical templates with:\n'
  for path in "${skipped_paths[@]}"; do
    # Map the dst path back to the template source
    case "$path" in
      .github/copilot-instructions.md)
        src_rel="copilot-instructions.md" ;;
      .github/workflows/*)
        src_rel="workflows/${path##*/}" ;;
      *)
        src_rel="$path" ;;
    esac
    printf '  diff -u %s %s/%s\n' "$path" "$TEMPLATES_DIR" "$src_rel"
  done
fi

printf '\nFiles were left UNSTAGED. Review them, then commit when ready.\n'
