#!/usr/bin/env bash
set -Eeuo pipefail
echo "--- premium wording polish on product notes (same meaning, clean phrasing) ---"
node /opt/gsz-deploy/libsrc/polish_notes.js
echo "DONE"
