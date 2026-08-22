#!/usr/bin/env bash
# prereq-check: detect installed CLI tool versions for Git-Ape skills.
# Read-only. Emits one TSV row per tool: <name>\t<status>\t<version>\t<minimum>
# where <status> is one of: OK | OUTDATED | MISSING.

set -u

# Parse minimum versions to compare against.
declare -A MIN=(
  [az]="2.50"
  [gh]="2.0"
  [jq]="1.6"
  [git]="0"
)

vercmp() {
  # Returns 0 (true) if $1 >= $2 using version sort.
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${MIN[$1]}"
}

check() {
  local tool="$1"
  local extract="$2"
  if ! command -v "$tool" &>/dev/null; then
    emit "$tool" MISSING "-"
    return
  fi
  local found
  found="$(eval "$extract" 2>/dev/null)"
  found="${found:-unknown}"
  if [[ "${MIN[$tool]}" != "0" ]] && ! vercmp "$found" "${MIN[$tool]}"; then
    emit "$tool" OUTDATED "$found"
  else
    emit "$tool" OK "$found"
  fi
}

echo "Platform: $(uname -s) / $(uname -m)"
check az  "az version --query '\"azure-cli\"' -o tsv"
check gh  "gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"
check jq  "jq --version | grep -oE '[0-9]+\.[0-9]+[a-z]*'"
check git "git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'"
