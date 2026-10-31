#!/usr/bin/env bash
set -uo pipefail
echo "===== pm2 processes (find the WhatsApp bot + its status) ====="
pm2 list 2>/dev/null
echo
echo "===== recent bot log lines (why the WhatsApp session dropped) ====="
# grep across all pm2 logs for bot/session events, bounded
pm2 logs --nostream --lines 2500 2>/dev/null | grep -iE "wabot|whatsapp|baileys|logged out|logout|connection clos|disconnect|QR|reconnect|401|conflict|stream error" | tail -35
echo "--- end ---"
