#!/usr/bin/env bash
# check-track-4-prereqs.sh — Verify Track 4 prerequisites.
# T4 is executive briefing + guided demo. If the facilitator is doing the demo
# live, T2 prereqs apply for the facilitator only. Otherwise demo only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_LIVE="${T4_LIVE_DEMO:-yes}"

echo "=== Track 4: Executive Briefing -- prereq check ==="
echo ""

if [[ "$DEMO_LIVE" == "yes" ]]; then
  echo "Facilitator-led live demo mode (set T4_LIVE_DEMO=no for slides-only)."
  echo "Running Track 2 prereqs for the facilitator..."
  echo ""
  exec bash "$SCRIPT_DIR/check-track-2-prereqs.sh"
fi

echo "Slides-only mode -- no Azure required for attendees."
echo ""
echo "Manual checks:"
echo "  - Deck pdf/pptx open and readable: workshops/track-4-executive-briefing/4_executive-briefing_deck.{pdf,pptx}"
echo "  - Pre-recorded demo video backup (if no live demo): workshops/shared/recordings/track-4-demo.mp4"
echo ""
echo "Track 4 (slides-only) ready."
exit 0