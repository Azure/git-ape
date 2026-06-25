#!/usr/bin/env bash
# Scaffold the Git-Ape enterprise distribution files into a `.github-private`
# repository working copy.
#
# Usage:
#   .github/skills/git-ape-onboarding/scripts/scaffold-enterprise.sh [target_repo_root]
#
# Default target_repo_root: `git rev-parse --show-toplevel`, or the current
# working directory if not inside a git repo. Run it from inside your cloned
# `.github-private` repo, or pass that repo's path explicitly.
#
# Behavior:
# - Copies each template to its destination ONLY if destination does not exist
# - Prints "✓ Created" for new files, "⊝ Skipped" for collisions
# - Final line summarizes counts; lists skipped files at the end so the user
#   can reconcile them manually
# - NEVER runs git add / commit / push / PR — the resulting files are left
#   unstaged in the working copy
#
# This scaffolds the ENTERPRISE distribution layer (the `.github-private` repo),
# not a deployment repo. For per-repository CI onboarding, use scaffold-repo.sh.
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
  "github-private/README.md:README.md"
  "github-private/.github/copilot/managed-settings.json:.github/copilot/managed-settings.json"
  "github-private/agents/.gitkeep:agents/.gitkeep"
)

if [ -t 1 ]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=''; YELLOW=''; BOLD=''; RESET=''
fi

printf '%sScaffolding Git-Ape enterprise files into:%s %s\n\n' "$BOLD" "$RESET" "$TARGET_ROOT"

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
      README.md)
        src_rel="github-private/README.md" ;;
      .github/copilot/managed-settings.json)
        src_rel="github-private/.github/copilot/managed-settings.json" ;;
      agents/.gitkeep)
        src_rel="github-private/agents/.gitkeep" ;;
      *)
        src_rel="github-private/$path" ;;
    esac
    printf '  diff -u %s %s/%s\n' "$path" "$TEMPLATES_DIR" "$src_rel"
  done
fi

printf '\nFiles were left UNSTAGED. Review them, then commit and push to your '
printf '.github-private repo.\nThen finish setup in Enterprise → AI controls '
printf '(designate the org + create the ruleset).\n'
