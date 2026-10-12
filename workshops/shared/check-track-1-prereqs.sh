#!/usr/bin/env bash
# check-track-1-prereqs.sh — Verify Track 1 prerequisites.
# T1 has no Azure dependencies — only dev env + Copilot + Git-Ape extension.

set -uo pipefail
PASS=0; FAIL=0

green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
gray()  { printf "\033[90m%s\033[0m\n" "$*"; }

check() {
  # NOTE: $2 is a check command, always an in-script static literal below
  # (never user/argument input), so `eval` carries no injection risk here.
  # Do not pass externally-derived strings as $2.
  if eval "$2" >/dev/null 2>&1; then
    green "PASS $1"; PASS=$((PASS+1))
  else
    red "FAIL $1"
    [[ -n "${3:-}" ]] && gray "     fix: $3"
    FAIL=$((FAIL+1))
  fi
}

echo ""
echo "=== Track 1: Zero to Deploy -- prereq check ==="
echo ""
check "git installed" "command -v git" "Install git via your OS package manager"
check "VS Code or Codespaces present" "command -v code || [ -n \"${CODESPACES:-}\" ]" "Install VS Code or open a Codespace"
echo ""
echo "Manual checks (cannot be scripted):"
echo "  - GitHub Copilot subscription active at github.com/settings/copilot"
echo "  - Git-Ape extension visible in Copilot Chat extensions panel"
echo ""
echo "Summary: $PASS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1 || exit 0