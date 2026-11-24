#!/usr/bin/env bash
# stepZayronTrialModalVerifyOnce — make the trial POPUP match the page: when the number is already
# verified (account or this browser), the modal shows a "Verified" note instead of the number box and
# goes straight to generating (no number, no code). Patches /providers (adds verified flag) + ztrial.js.
# Safe: backup both files, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp routes/trial.js "$B/trial.js.bak"; cp public/ztrial.js "$B/ztrial.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; cp "$B/ztrial.js.bak" public/ztrial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

# --- 1) server: expose verified flag on /trial/providers ---
node - <<'APPLY'
const fs=require('fs');const F='routes/trial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('TRIAL ANCHOR x'+c+': '+o.slice(0,55));process.exit(5);}s=s.split(o).join(n);}
rep(
`      res.json({ ok: true, providers: out, whatsapp: (data.whatsapp || '').replace(/[^0-9]/g, ''), maxProviders: _maxP2, usedCount: _usedCount, remaining: (_maxP2 > 0 ? Math.max(0, _maxP2 - _usedCount) : null) });`,
`      let _vpP = null; try { _vpP = await _verifiedPhone(req); } catch (e) {}
      res.json({ ok: true, providers: out, whatsapp: (data.whatsapp || '').replace(/[^0-9]/g, ''), maxProviders: _maxP2, usedCount: _usedCount, remaining: (_maxP2 > 0 ? Math.max(0, _maxP2 - _usedCount) : null), verified: !!_vpP, verifiedLast: _vpP ? String(_vpP).slice(-4) : '' });`);
fs.writeFileSync(F,s);console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "trial.js patch failed"; exit 1; }

# --- 2) client: ztrial.js skips the number box when verified ---
node - <<'APPLY'
const fs=require('fs');const F='public/ztrial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('ZTRIAL ANCHOR x'+c+': '+o.slice(0,55));process.exit(5);}s=s.split(o).join(n);}
// a) declare the two flags
rep(`  var WA = '';`, `  var WA = '';
  var VERIFIED = false; var VLAST = '';`);
// b) set them from /providers
rep(
`TREMAIN = (typeof d.remaining==='number'?d.remaining:null); }`,
`TREMAIN = (typeof d.remaining==='number'?d.remaining:null); VERIFIED = !!d.verified; VLAST = d.verifiedLast || ''; }`);
// c) render a Verified note instead of the number box
rep(
`    var phoneField = hasPhone ? '' : '<div class="zt-field"><label>WhatsApp number <span class="rq">*</span></label><div id="ztPhoneBox"></div></div>';`,
`    var phoneField = VERIFIED
      ? '<div class="zt-field"><label>WhatsApp number</label><div style="display:flex;align-items:center;gap:8px;padding:12px 14px;border:1px solid var(--line,rgba(12,30,80,.12));border-radius:12px;background:#f0fdf6;color:#0e9257;font-weight:700">Verified ✓ <span style="color:var(--muted,#5b6b8c);font-weight:600">ending ••• ' + esc(VLAST) + '</span></div></div>'
      : (hasPhone ? '' : '<div class="zt-field"><label>WhatsApp number <span class="rq">*</span></label><div id="ztPhoneBox"></div></div>');`);
fs.writeFileSync(F,s);console.log('ztrial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "ztrial.js patch failed - reverting"; revert; exit 1; }

node --check routes/trial.js || { echo "trial.js syntax error - reverting"; revert; exit 1; }
node --check public/ztrial.js || { echo "ztrial.js syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: the trial popup now skips the number box when verified (one-tap). healthz=200"
