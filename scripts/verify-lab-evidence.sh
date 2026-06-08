#!/usr/bin/env bash
# verify-lab-evidence.sh -- diff freshly-captured transcript against committed one.
#
# Usage:
#   bash scripts/verify-lab-evidence.sh <lab-md-file>
#
# Captures the lab's commands into a temp file, redacts, then diffs against
# the committed transcript. Exits 0 if no drift, 1 if drift detected.
# Drift-tolerant: ignores whitespace at EOL and numeric durations.

set -uo pipefail

LAB="${1:-}"
if [[ -z "$LAB" || ! -f "$LAB" ]]; then
  echo "usage: $0 <lab-md-file>" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB_DIR=$(dirname "$LAB")
LAB_BASE=$(basename "$LAB" .md)
COMMITTED="$LAB_DIR/evidence/${LAB_BASE}-transcript.md"

if [[ ! -f "$COMMITTED" ]]; then
  echo "no committed transcript at $COMMITTED -- run capture-lab-evidence.sh first"
  exit 0   # no transcript yet is OK (advisory only)
fi

TMP_NEW=$(mktemp)
bash "$REPO_ROOT/scripts/capture-lab-evidence.sh" "$LAB" >/dev/null
cp "$LAB_DIR/evidence/${LAB_BASE}-transcript.md" "$TMP_NEW"
# Restore committed (since capture overwrites)
git checkout HEAD -- "$COMMITTED" 2>/dev/null || true

# Diff with whitespace-and-duration tolerance.
# 1. strip "> Captured:" line (always changes)
# 2. strip trailing whitespace
# 3. normalize "Took N.Ns" -> "Took <N>s"
norm() {
  sed -e '/^> Captured:/d' \
      -e 's/[[:space:]]\+$//' \
      -e 's/Took [0-9.]\+s/Took <N>s/g' \
      "$1"
}

if diff -u <(norm "$COMMITTED") <(norm "$TMP_NEW"); then
  echo "OK: $COMMITTED matches"
  rm -f "$TMP_NEW"
  exit 0
else
  echo ""
  echo "DRIFT in $COMMITTED" >&2
  rm -f "$TMP_NEW"
  exit 1
fi
