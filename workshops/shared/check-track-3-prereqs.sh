#!/usr/bin/env bash
# check-track-3-prereqs.sh — Verify Track 3 prerequisites.
# T3 extends Track 2 with extra resource providers and the Copilot Coding Agent.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Track 3: Platform Engineering -- prereq check ==="
echo ""
echo "Track 3 builds on Track 2. Running the Track 2 check first..."
echo ""

if bash "$SCRIPT_DIR/check-track-2-prereqs.sh"; then
  T2_OK=1
else
  T2_OK=0
fi

echo ""
echo "--- T3-specific: additional providers ---"
PASS=0; FAIL=0
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
gray()  { printf "\033[90m%s\033[0m\n" "$*"; }

for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.ContainerRegistry; do
  if az provider show --namespace $ns --query 'registrationState' -o tsv 2>/dev/null | grep -qx Registered; then
    green "PASS $ns registered"; PASS=$((PASS+1))
  else
    red "FAIL $ns not registered"
    gray "     fix: az provider register --namespace $ns --wait"
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "Manual checks:"
echo "  - GitHub Copilot Coding Agent enabled in repo Settings -> Code & automation"
echo "  - Two GitHub environments exist (azure-deploy, azure-destroy)"
echo "  - Allow GH Actions to create and approve PRs enabled (Settings -> Actions -> General)"
echo ""
echo "Summary (T3 extras): $PASS passed, $FAIL failed"
if [[ $T2_OK -ne 1 || $FAIL -gt 0 ]]; then
  red "Track 3 NOT ready -- resolve failures above."
  exit 1
fi
green "Track 3 ready."
exit 0