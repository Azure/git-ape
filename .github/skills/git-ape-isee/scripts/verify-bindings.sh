#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
DEPLOYMENT_ID=""
BINDINGS=""
STATUS=""
MODE="unknown"
STATUS_WRITTEN=false

usage() {
  echo "Usage: $0 --deployment-id <id> [--bindings FILE] [--status-output FILE]" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-id) DEPLOYMENT_ID="${2:-}"; shift 2 ;;
    --bindings) BINDINGS="${2:-}"; shift 2 ;;
    --status-output) STATUS="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ "$DEPLOYMENT_ID" =~ ^[A-Za-z0-9._-]+$ ]] || usage

DEPLOY_DIR="$ROOT/.azure/deployments/$DEPLOYMENT_ID"
BINDINGS="${BINDINGS:-$DEPLOY_DIR/isee-bindings.json}"
STATUS="${STATUS:-$DEPLOY_DIR/governance-status.json}"
PRODUCER="$ROOT/.github/git-ape/records/git-ape-records.sh"
if [[ ! -f "$PRODUCER" ]]; then
  PRODUCER="$ROOT/.github/skills/git-ape-records/scripts/git-ape-records.sh"
fi

write_status() {
  local status="$1"
  local mode="$2"
  local reason="$3"
  local temporary
  mkdir -p "$(dirname "$STATUS")"
  temporary="$(dirname "$STATUS")/.$(basename "$STATUS").$$.tmp"
  if command -v jq >/dev/null; then
    jq -n \
      --arg deploymentId "$DEPLOYMENT_ID" \
      --arg status "$status" \
      --arg mode "$mode" \
      --arg reason "$reason" \
      '{schemaVersion:"git-ape-governance-status/v1",deploymentId:$deploymentId,status:$status,mode:$mode,reason:(if $reason == "" then null else $reason end)}' \
      > "$temporary"
  else
    # Without jq, emit a minimal record; DEPLOYMENT_ID is already restricted to
    # JSON-safe characters and the reason is sanitised.
    reason="${reason//\\//}"
    reason="${reason//\"/\'}"
    printf '{"schemaVersion":"git-ape-governance-status/v1","deploymentId":"%s","status":"%s","mode":"%s","reason":"%s"}\n' \
      "$DEPLOYMENT_ID" "$status" "$mode" "$reason" > "$temporary"
  fi
  mv "$temporary" "$STATUS"
  STATUS_WRITTEN=true
}

# Every blocked preflight records a failed status before exiting so a stale
# "passed" result can never survive a later failure.
block() {
  local reason="$1"
  write_status "failed" "$MODE" "$reason"
  echo "ISEE preflight blocked: $reason" >&2
  exit 1
}

on_exit() {
  local rc=$?
  if [[ $rc -ne 0 && "$STATUS_WRITTEN" != "true" ]]; then
    write_status "failed" "$MODE" "preflight terminated unexpectedly (exit $rc)" || true
  fi
}
trap on_exit EXIT

if [[ ! -f "$BINDINGS" ]]; then
  if [[ "${GIT_APE_ISEE_REQUIRED:-false}" == "true" ]]; then
    MODE="required"
    block "required bindings are missing"
  fi
  write_status "standalone" "standalone" ""
  echo "ISEE preflight: standalone Git-Ape (no bindings file)."
  exit 0
fi

command -v jq >/dev/null || block "jq is required"
[[ -f "$PRODUCER" ]] || block "native record producer missing"

jq -e --arg id "$DEPLOYMENT_ID" '
  .schemaVersion == "git-ape-isee-bindings/v1" and
  .deploymentId == $id and
  (.governanceMode == "optional" or .governanceMode == "required") and
  (.intentRecords | type == "array") and
  (.intentRecords | length > 0) and
  (all(.intentRecords[];
    (.path | type == "string") and
    (.fingerprint | test("^sha256:[0-9a-f]{64}$")) and
    ((.requireRatified // false) | type == "boolean"))) and
  (.governanceMode != "required" or
    all(.intentRecords[]; .requireRatified == true)) and
  (.structureRecords | type == "array") and
  (all(.structureRecords[];
    (.path | type == "string") and
    (.fingerprint | test("^sha256:[0-9a-f]{64}$")))) and
  (.executionManifest == null or
    ((.executionManifest.path | type == "string") and
     (.executionManifest.digest | test("^sha256:[0-9a-f]{64}$")))) and
  (.gates | type == "array") and
  (.evidenceRequirements | type == "array") and
  (.artifacts.template.path | type == "string") and
  (.artifacts.template.digest | test("^sha256:[0-9a-f]{64}$")) and
  (.artifacts.parameters == null or
    ((.artifacts.parameters.path | type == "string") and
     (.artifacts.parameters.digest | test("^sha256:[0-9a-f]{64}$")))) and
  (.artifacts.additional | type == "array") and
  (all(.artifacts.additional[];
    (.path | type == "string") and
    (.digest | test("^sha256:[0-9a-f]{64}$"))))
' "$BINDINGS" >/dev/null 2>&1 || block "invalid bindings contract"

MODE=$(jq -r '.governanceMode' "$BINDINGS")

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null; then
    sha256sum "$path" | awk '{print "sha256:" $1}'
  else
    shasum -a 256 "$path" | awk '{print "sha256:" $1}'
  fi
}

# Sets RESOLVED_PATH in the current shell so a blocked path records a failed
# status instead of exiting only a command-substitution subshell.
RESOLVED_PATH=""
resolve_path() {
  local relative="$1"
  local candidate parent
  [[ "$relative" != /* && "$relative" != ".." && "$relative" != ../* && "$relative" != */../* && "$relative" != */.. ]] ||
    block "unsafe path $relative"
  candidate="$ROOT/$relative"
  parent=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P) ||
    block "path parent not found: $relative"
  [[ ! -L "$candidate" ]] ||
    block "symbolic links are not allowed in bindings: $relative"
  RESOLVED_PATH="$parent/$(basename "$candidate")"
  case "$RESOLVED_PATH" in
    "$ROOT"|"$ROOT"/*) ;;
    *) block "path escapes repository root: $relative" ;;
  esac
}

verify_artifact() {
  local path="$1"
  local expected="$2"
  local actual
  resolve_path "$path"
  [[ -f "$RESOLVED_PATH" ]] || block "artifact not found: $path"
  actual=$(sha256_file "$RESOLVED_PATH")
  [[ "$actual" == "$expected" ]] || block "artifact digest mismatch: $path"
}

while IFS=$'\t' read -r path expected require_ratified; do
  resolve_path "$path"
  absolute="$RESOLVED_PATH"
  [[ -f "$absolute" ]] || block "Intent record not found: $path"
  actual=$(bash "$PRODUCER" fingerprint --profile adrp "$absolute") ||
    block "could not fingerprint Intent record: $path"
  [[ "$actual" == "$expected" ]] || block "ADRP fingerprint mismatch: $path"
  if command -v adrp >/dev/null; then
    ARGS=(validate --target "$absolute")
    [[ "$require_ratified" == "true" ]] && ARGS+=(--require-ratified)
    adrp "${ARGS[@]}" >/dev/null || block "ADRP validation failed: $path"
  elif [[ "$MODE" == "required" ]]; then
    block "ADRP CLI required for governed Intent validation"
  else
    echo "ISEE preflight warning: ADRP CLI unavailable; native fingerprint matched." >&2
  fi
done < <(jq -r '.intentRecords[] | [.path, .fingerprint, (.requireRatified // false)] | @tsv' "$BINDINGS")

while IFS=$'\t' read -r path expected; do
  resolve_path "$path"
  absolute="$RESOLVED_PATH"
  [[ -f "$absolute" ]] || block "Structure record not found: $path"
  actual=$(bash "$PRODUCER" fingerprint --profile asrp "$absolute") ||
    block "could not fingerprint Structure record: $path"
  [[ "$actual" == "$expected" ]] || block "ASRP fingerprint mismatch: $path"
  if command -v asrp >/dev/null; then
    asrp validate "$absolute" >/dev/null || block "ASRP validation failed: $path"
  elif [[ "$MODE" == "required" ]]; then
    block "ASRP CLI required for governed Structure validation"
  else
    echo "ISEE preflight warning: ASRP CLI unavailable; native fingerprint matched." >&2
  fi
done < <(jq -r '.structureRecords[] | [.path, .fingerprint] | @tsv' "$BINDINGS")

if [[ $(jq -r '.executionManifest != null' "$BINDINGS") == "true" ]]; then
  verify_artifact \
    "$(jq -r '.executionManifest.path' "$BINDINGS")" \
    "$(jq -r '.executionManifest.digest' "$BINDINGS")"
fi

verify_artifact \
  "$(jq -r '.artifacts.template.path' "$BINDINGS")" \
  "$(jq -r '.artifacts.template.digest' "$BINDINGS")"

if [[ $(jq -r '.artifacts.parameters != null' "$BINDINGS") == "true" ]]; then
  verify_artifact \
    "$(jq -r '.artifacts.parameters.path' "$BINDINGS")" \
    "$(jq -r '.artifacts.parameters.digest' "$BINDINGS")"
fi

while IFS=$'\t' read -r path expected; do
  verify_artifact "$path" "$expected"
done < <(jq -r '.artifacts.additional[] | [.path, .digest] | @tsv' "$BINDINGS")

write_status "passed" "$MODE" ""
echo "ISEE preflight passed: $DEPLOYMENT_ID ($MODE governance)."
