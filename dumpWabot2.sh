#!/usr/bin/env bash
# dumpWabot2.sh — read-only. The verification bot's config, helpers, and the FULL message handler
# (plain line ranges — no forward-context awk bug this time).
set -uo pipefail
F=/opt/gsz-wabot/bot.js
win(){ awk -v s="$1" -v e="$2" 'NR>=s&&NR<=e{printf "%4d| %s\n",NR,$0}' "$F"; }
echo "### 1-30 (config / env / http helper to website) ###"; win 1 30
echo; echo "### 55-95 (extractText + sendText + any website call helper) ###"; win 55 95
echo; echo "### 119-194 (messages.upsert handler — the full body) ###"; win 119 194
echo "== END =="
