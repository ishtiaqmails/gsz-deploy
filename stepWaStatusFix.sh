#!/usr/bin/env bash
# stepWaStatusFix.sh — fix the admin WhatsApp page never updating.
# routes/wabot.js calls the bot's /qr endpoint, but the bot serves /status. This
# repoints it to /status (so connected/user/QR all read correctly) and auto-syncs
# wa_verify_number to the bot's actual connected number (so changing the bot number
# propagates to the verification links automatically).
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s); F="$GSZ/routes/wabot.js"; BAK="$F.bak.$TS"
restore(){ echo "!! failed — rolling back"; [ -f "$BAK" ] && cp -f "$BAK" "$F"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
cp -f "$F" "$BAK"
export F
node <<'NODE'
const fs=require('fs'); const F=process.env.F;
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('WA_STATUS_FIX')>=0){ console.log('   already patched'); process.exit(0); }
function rep(o,n){ const c=s.split(o).length-1; if(c!==1) throw new Error('anchor ('+c+'): '+o.slice(0,40)); s=s.split(o).join(n); }
// 1) call /status instead of the non-existent /qr
rep("const d = await getJson(origin, '/qr', secret);", "const d = await getJson(origin, '/status', secret); /*WA_STATUS_FIX*/");
// 2) auto-sync wa_verify_number to the bot's connected number + expose number
rep("    res.json({ ok: true, reachable: true, status: d.status || 'unknown', connected: !!d.connected, user: d.user || null, qrDataUrl: qrDataUrl });",
    "    try { if (d.connected && d.number) { await pool.query(\"INSERT INTO wa_settings(key,value) VALUES('wa_verify_number',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now() WHERE wa_settings.value IS DISTINCT FROM $1\", [String(d.number).replace(/[^0-9]/g,'')]); } } catch (e) {}\n    res.json({ ok: true, reachable: true, status: (d.connected ? 'connected' : (d.qr ? 'qr' : 'connecting')), connected: !!d.connected, number: d.number || null, user: d.user || null, qrDataUrl: qrDataUrl });");
fs.writeFileSync(F,s); console.log('   wabot.js repointed /qr -> /status + number auto-sync');
NODE
node --check "$F"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy. Reload /admin/wabot — it should now show Connected (or a scannable QR). Backup: $BAK"
