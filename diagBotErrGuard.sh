#!/usr/bin/env bash
# diagBotErrGuard — does gszwabot have global error guards (uncaughtException/unhandledRejection) and is its message
# handler wrapped so a libsignal throw doesn't kill the process? READ-ONLY.
set +e
cd /opt/gsz-wabot || { echo "no /opt/gsz-wabot"; exit 0; }
echo "### process-level error handlers present? ###"
grep -n "uncaughtException\|unhandledRejection\|process.on" bot.js | head
echo
echo "### message/event handlers (are they try/caught?) ###"
grep -n "ev.on(\|messages.upsert\|messaging-history\|async (" bot.js | head -20
echo
echo "### first 12 lines (requires + any top-level setup) ###"
sed -n '1,14p' bot.js
echo
echo "### tail end (where it all starts) ###"
sed -n "$(($(wc -l < bot.js)-14)),\$p" bot.js
echo DONE
