#!/usr/bin/env bash
set -Eeuo pipefail
echo "--- removing notes that just repeat the plan label (device/login counts) ---"
node /opt/gsz-deploy/libsrc/clean_notes2.js
echo "DONE"
