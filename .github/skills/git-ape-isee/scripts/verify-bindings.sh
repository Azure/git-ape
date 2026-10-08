#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
DEPLOYMENT_ID=""

usage() {
  echo "Usage: $0 --deployment-id <id>" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deployment-id) DEPLOYMENT_ID="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ "$DEPLOYMENT_ID" =~ ^[A-Za-z0-9._-]+$ ]] || usage

DEPLOY_DIR="$ROOT/.azure/deployments/$DEPLOYMENT_ID"
BINDINGS="$DEPLOY_DIR/isee-bindings.json"
STATUS="$DEPLOY_DIR/governance-status.json"
PRODUCER="$ROOT/.github/git-ape/records/git-ape-records.sh"
if [[ ! -f "$PRODUCER" ]]; then
  PRODUCER="$ROOT/.github/skills/git-ape-records/scripts/git-ape-records.sh"
fi

write_status() {
  local status="$1"
  local mode="$2"
  local reason="$3"
  jq -n \
    --arg deploymentId "$DEPLOYMENT_ID" \
    --arg status "$status" \
    --arg mode "$mode" \
    --arg reason "$reason" \
    '{schemaVersion:"git-ape-governance-status/v1",deploymentId:$deploymentId,status:$status,mode:$mode,reason:(if $reason == "" then null else $reason end)}' \
    > "$STATUS"
}

if [[ ! -f "$BINDINGS" ]]; then
  if [[ "${GIT_APE_ISEE_REQUIRED:-false}" == "true" ]]; then
    write_status "failed" "required" "required bindings are missing"
    echo "ISEE preflight blocked: $BINDINGS is required but missing." >&2
    exit 1
  fi
  write_status "standalone" "standalone" ""
  echo "ISEE preflight: standalone Git-Ape (no bindings file)."
  exit 0
fi

command -v jq >/dev/null || { echo "ISEE preflight blocked: jq is required." >&2; exit 1; }
[[ -f "$PRODUCER" ]] || { echo "ISEE preflight blocked: native record producer missing." >&2; exit 1; }

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
' "$BINDINGS" >/dev/null || {
  write_status "failed" "unknown" "invalid bindings contract"
  echo "ISEE preflight blocked: invalid bindings contract." >&2
  exit 1
}

MODE=$(jq -r '.governanceMode' "$BINDINGS")

sha256_file() {
  local path="$1"
  if command -v sha256sum >/dev/null; then
    sha256sum "$path" | awk '{print "sha256:" $1}'
  else
    shasum -a 256 "$path" | awk '{print "sha256:" $1}'
  fi
}

resolve_path() {
  local relative="$1"
  local candidate parent resolved
  [[ "$relative" != /* && "$relative" != ".." && "$relative" != ../* && "$relative" != */../* && "$relative" != */.. ]] || {
    echo "ISEE preflight blocked: unsafe path $relative" >&2
    exit 1
  }
  candidate="$ROOT/$relative"
  parent=$(cd "$(dirname "$candidate")" 2>/dev/null && pwd -P) || {
    echo "ISEE preflight blocked: path parent not found: $relative" >&2
    exit 1
  }
  [[ ! -L "$candidate" ]] || {
    echo "ISEE preflight blocked: symbolic links are not allowed in bindings: $relative" >&2
    exit 1
  }
  resolved="$parent/$(basename "$candidate")"
  case "$resolved" in
    "$ROOT"|"$ROOT"/*) printf '%s\n' "$resolved" ;;
    *)
      echo "ISEE preflight blocked: path escapes repository root: $relative" >&2
      exit 1
      ;;
  esac
}

verify_artifact() {
  local path="$1"
  local expected="$2"
  local absolute
  absolute=$(resolve_path "$path")
  [[ -f "$absolute" ]] || { echo "ISEE preflight blocked: artifact not found: $path" >&2; exit 1; }
  local actual
  actual=$(sha256_file "$absolute")
  [[ "$actual" == "$expected" ]] || {
    echo "ISEE preflight blocked: artifact digest mismatch: $path" >&2
    exit 1
  }
}

while IFS=$'\t' read -r path expected require_ratified; do
  absolute=$(resolve_path "$path")
  [[ -f "$absolute" ]] || { echo "ISEE preflight blocked: Intent record not found: $path" >&2; exit 1; }
  actual=$(bash "$PRODUCER" fingerprint --profile adrp "$absolute")
  [[ "$actual" == "$expected" ]] || { echo "ISEE preflight blocked: ADRP fingerprint mismatch: $path" >&2; exit 1; }
  if command -v adrp >/dev/null; then
    ARGS=(validate --target "$absolute")
    [[ "$require_ratified" == "true" ]] && ARGS+=(--require-ratified)
    adrp "${ARGS[@]}" >/dev/null
  elif [[ "$MODE" == "required" ]]; then
    echo "ISEE preflight blocked: ADRP CLI required for governed Intent validation." >&2
    exit 1
  else
    echo "ISEE preflight warning: ADRP CLI unavailable; native fingerprint matched." >&2
  fi
done < <(jq -r '.intentRecords[] | [.path, .fingerprint, (.requireRatified // false)] | @tsv' "$BINDINGS")

while IFS=$'\t' read -r path expected; do
  absolute=$(resolve_path "$path")
  [[ -f "$absolute" ]] || { echo "ISEE preflight blocked: Structure record not found: $path" >&2; exit 1; }
  actual=$(bash "$PRODUCER" fingerprint --profile asrp "$absolute")
  [[ "$actual" == "$expected" ]] || { echo "ISEE preflight blocked: ASRP fingerprint mismatch: $path" >&2; exit 1; }
  if command -v asrp >/dev/null; then
    asrp validate "$absolute" >/dev/null
  elif [[ "$MODE" == "required" ]]; then
    echo "ISEE preflight blocked: ASRP CLI required for governed Structure validation." >&2
    exit 1
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
