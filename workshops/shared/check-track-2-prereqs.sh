#!/usr/bin/env bash
# check-track-2-prereqs.sh — Verify Track 2 prerequisites BEFORE the workshop.
#
# Usage:
#   bash workshops/shared/check-track-2-prereqs.sh
#
# Exits 0 with "ready for Track 2" if every check passes.
# Exits non-zero with the exact remediation command on the first failure.

set -uo pipefail

PASS=0; FAIL=0; WARN=0

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
gray()   { printf "\033[90m%s\033[0m\n" "$*"; }

check() {
  local label="$1"; local cmd="$2"; local fix="${3:-}"
  # NOTE: $cmd is always an in-script static literal at the call sites below
  # (never user/argument input), so `eval` carries no injection risk here.
  # Do not pass externally-derived strings as the command argument.
  if eval "$cmd" >/dev/null 2>&1; then
    green "PASS $label"; PASS=$((PASS+1))
  else
    red "FAIL $label"
    [[ -n "$fix" ]] && gray "     fix: $fix"
    FAIL=$((FAIL+1))
  fi
}

warn_check() {
  local label="$1"; local cmd="$2"; local advice="${3:-}"
  # Same invariant as check(): $cmd is always an in-script static literal.
  if eval "$cmd" >/dev/null 2>&1; then
    green "PASS $label"; PASS=$((PASS+1))
  else
    yellow "WARN $label"
    [[ -n "$advice" ]] && gray "     note: $advice"
    WARN=$((WARN+1))
  fi
}

echo ""
echo "=== Track 2: Deploy Like a Pro -- prereq check ==="
echo ""

echo "--- 1. CLI tools ---"
check "Azure CLI (az) installed"  "command -v az"  "brew install azure-cli"
check "GitHub CLI (gh) installed" "command -v gh"  "brew install gh"
check "jq installed"              "command -v jq"  "brew install jq"
check "git installed"             "command -v git" ""

echo ""
echo "--- 2. Authentication ---"
check "Azure CLI logged in"   "az account show"  "az login"
check "GitHub CLI logged in"  "gh auth status"   "gh auth login"

echo ""
echo "--- 3. Azure subscription state ---"
check "Subscription state is Enabled" \
  "az account show --query 'state' -o tsv | grep -qx Enabled" \
  "az account set --subscription <NAME or ID>"

echo ""
echo "--- 4. Required resource providers ---"
for ns in Microsoft.Web Microsoft.Storage Microsoft.Insights Microsoft.Sql Microsoft.KeyVault; do
  check "$ns registered" \
    "az provider show --namespace $ns --query 'registrationState' -o tsv | grep -qx Registered" \
    "az provider register --namespace $ns --wait"
done

echo ""
echo "--- 5. RBAC for Lab 1 (onboarding) ---"
SP_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
if [[ -n "$SP_ID" ]]; then
  warn_check "Has Owner or User Access Administrator" \
    "az role assignment list --assignee $SP_ID --all --query \"[?roleDefinitionName=='Owner' || roleDefinitionName=='User Access Administrator']\" -o tsv | grep -q ." \
    "Needed only for Lab 1. If absent, you can do review-only path for Lab 1."
else
  yellow "WARN Could not look up signed-in user (az ad signed-in-user show failed)"
  WARN=$((WARN+1))
fi

echo ""
echo "--- 6. GitHub repo settings ---"
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || echo "")
if [[ -n "$REPO" ]]; then
  green "PASS Detected GitHub repo: $REPO"
  warn_check "Allow GH Actions to create and approve PRs (advisory)" \
    "gh api repos/$REPO --jq '.allow_auto_merge' >/dev/null" \
    "This setting is not queryable via API; verify manually in Settings -> Actions -> General -> Workflow permissions"
else
  yellow "WARN Could not detect GitHub repo (gh repo view failed)"
  WARN=$((WARN+1))
fi

echo ""
echo "==================================================="
echo "Summary: $PASS passed, $WARN warnings, $FAIL failed"
echo "==================================================="
if [[ $FAIL -gt 0 ]]; then
  red "Track 2 NOT ready. Fix the failed checks above and re-run."
  exit 1
fi
if [[ $WARN -gt 0 ]]; then
  yellow "Track 2 mostly ready. Review warnings -- some labs may be affected."
  exit 0
fi
green "Track 2 ready."
exit 0