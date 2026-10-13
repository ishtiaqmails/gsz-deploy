#!/usr/bin/env bash
# Semantic brain — feasibility check. Installs the local MiniLM model in a SEPARATE folder
# (/opt/gsz-sem), isolated from the live store app, and runs a self-test proving it matches
# questions by meaning. Nothing in the running site is touched. Safe to re-run.
set -Eeuo pipefail
SEM=/opt/gsz-sem; SRC=/opt/gsz-deploy/libsrc/sem
mkdir -p "$SEM"
cp -f "$SRC/package.json" "$SEM/package.json"
cp -f "$SRC/selftest.mjs" "$SEM/selftest.mjs"
cd "$SEM"
echo "installing semantic deps (one-time; ~100-200MB, a minute or two)…"
npm install --no-audit --no-fund 2>&1 | tail -6
echo
echo "--- semantic self-test (first run also downloads the ~23MB model) ---"
node selftest.mjs
echo
echo "DONE — if you see 'SEMANTIC OK' with sensible matches above, the brain runs on your VPS."
