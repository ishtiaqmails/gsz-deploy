#!/usr/bin/env bash
set -Eeuo pipefail
echo "--- premium note cleanup (strip redundant device/login counts; drop plan-echo notes) ---"
node /opt/gsz-deploy/libsrc/clean_notes3.js
echo "DONE"
