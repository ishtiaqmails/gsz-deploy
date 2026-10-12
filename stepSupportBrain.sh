#!/usr/bin/env bash
# Live Support Bot — Stage 1 (knowledge base) + Stage 2 (answer engine).
# Deploys the two self-contained libs and proves them against the REAL catalog (no UI yet).
# Pure library files; nothing imports them until Stage 3 wires the route, so no restart needed.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
cp -f "$SRC/supportkb.js"  "$GSZ/lib/supportkb.js"
cp -f "$SRC/supportbot.js" "$GSZ/lib/supportbot.js"
node --check "$GSZ/lib/supportkb.js"  && echo "   supportkb.js ok"
node --check "$GSZ/lib/supportbot.js" && echo "   supportbot.js ok"
echo "--- proof: build KB + answer real questions from live data ---"
node "$SRC/support_proof.js" "$GSZ"
echo "DONE — Stage 1 (KB) + Stage 2 (answer engine) are live libs. Next: wire the chat route + Hub widget."
