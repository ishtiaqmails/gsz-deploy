#!/usr/bin/env bash
# stepWaControlCenter.sh — ship the WhatsApp Control Center.
#  - routes/wabot.js  : connection(status+QR) + numbers + toggles + bot actions (incl the /status fix)
#  - views/admin/wabot.ejs : the control panel (light admin shell, live-polling)
#  - routes/trials.js : make the trial WhatsApp gate respect the new require_wa_trial toggle
# Checkout gate (require_wa_verify) already exists in checkout.js — the panel just drives it.
# Numbers read live from settings/wa_settings, so a change propagates everywhere at once.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s); BAKDIR="$GSZ/.wabak.$TS"; mkdir -p "$BAKDIR"
WB="$GSZ/routes/wabot.js"; WV="$GSZ/views/admin/wabot.ejs"; TR="$GSZ/routes/trials.js"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/wabot.js" ] && cp -f "$BAKDIR/wabot.js" "$WB"; [ -f "$BAKDIR/wabot.ejs" ] && cp -f "$BAKDIR/wabot.ejs" "$WV"; [ -f "$BAKDIR/trials.js" ] && cp -f "$BAKDIR/trials.js" "$TR"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR

echo "==> backup"
cp -f "$WB" "$BAKDIR/wabot.js"; cp -f "$WV" "$BAKDIR/wabot.ejs" 2>/dev/null || true; cp -f "$TR" "$BAKDIR/trials.js"

echo "==> deploy control center route + view"
cp -f "$DEPLOY/routes/wabot.js" "$WB"
cp -f "$DEPLOY/views/admin/wabot.ejs" "$WV"

echo "==> wire trial gate to require_wa_trial toggle"
export TR
node <<'NODE'
const fs=require('fs'); const F=process.env.TR;
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('REQUIRE_WA_TRIAL')>=0){ console.log('   trials already wired'); process.exit(0); }
const anchor="if (!v.waOk) return ajax ? res.json({ ok: false, reason: 'wa' }) : res.redirect('/account/whatsapp');";
const n=s.split(anchor).length-1;
if(n!==1) throw new Error('trials anchor not unique/found ('+n+')');
const repl="let _trialGate = true; try { const _rqt = (await pool.query(\"SELECT value FROM wa_settings WHERE key='require_wa_trial'\")).rows[0]; _trialGate = !(_rqt && String(_rqt.value) === 'off'); } catch (e) {} /*REQUIRE_WA_TRIAL*/\n    if (_trialGate && !v.waOk) return ajax ? res.json({ ok: false, reason: 'wa' }) : res.redirect('/account/whatsapp');";
s=s.split(anchor).join(repl);
fs.writeFileSync(F,s); console.log('   trials.js gate now toggle-aware');
NODE

echo "==> node --check + ejs compile"
node --check "$WB"; node --check "$TR"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");ejs.compile(fs.readFileSync("'"$WV"'","utf8"),{filename:"'"$WV"'"});console.log("   view compiles OK")'

echo "==> restart"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE — open https://galaxyzayron.store/admin/wabot"
echo "  • Connection shows Connected / live QR"
echo "  • Edit store/owner/sales/support numbers (bot number auto-syncs)"
echo "  • Toggles: require WhatsApp at checkout / for trials, verification on/off, order notifications"
echo "Backups: $BAKDIR"
