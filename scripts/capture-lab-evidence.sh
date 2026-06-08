#!/usr/bin/env bash
# capture-lab-evidence.sh -- record commands from a lab into a transcript.
#
# Usage:
#   bash scripts/capture-lab-evidence.sh <lab-md-file>
#
# Scans the lab markdown for ```bash blocks that contain a # capture-evidence
# directive in a comment line. Runs each such command and writes the literal
# output to evidence/<lab-basename>-transcript.md alongside the lab. Pipes
# through scripts/redact-evidence.js.
#
# Does NOT run @git-ape chat invocations or any command needing interactive
# approval; those are facilitator-captured during dry-run.

set -uo pipefail

LAB="${1:-}"
if [[ -z "$LAB" || ! -f "$LAB" ]]; then
  echo "usage: $0 <lab-md-file>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_DIR=$(dirname "$LAB")
LAB_BASE=$(basename "$LAB" .md)
OUT_DIR="$LAB_DIR/evidence"
OUT_FILE="$OUT_DIR/${LAB_BASE}-transcript.md"
mkdir -p "$OUT_DIR"

TMP_RAW=$(mktemp)
TMP_REDACT=$(mktemp)

{
  echo "# ${LAB_BASE} Transcript"
  echo ""
  echo "> Captured: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "> Environment: $(uname -s) ${USER:-unknown}"
  echo "> Subscription: <REDACTED-SUB>"
  echo ""
  echo "## Captured commands"
  echo ""
} > "$TMP_RAW"

python3 "$REPO_ROOT/scripts/_extract-capture-cmds.py" "$LAB" >> "$TMP_RAW"

node "$REPO_ROOT/scripts/redact-evidence.js" < "$TMP_RAW" > "$TMP_REDACT"
mv "$TMP_REDACT" "$OUT_FILE"
rm -f "$TMP_RAW"

echo "Wrote: $OUT_FILE"
