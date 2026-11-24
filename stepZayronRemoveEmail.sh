#!/usr/bin/env bash
# stepZayronRemoveEmail — remove EMAIL entirely from zayron (pure WhatsApp only).
#  1. retire the Gmail bank-alert poller: zayron-mail process + mailService.js + lib/mailPoller.js
#     (redundant — bank payments now verify through the shared gsz-api ledger).
#  2. drop the optional customer email field from signup + the email row on the account page.
# NOT touched: payMatch/payParse/payhook/adminpay (local matcher fallback — retired at switch-on),
# admin customer views (show blank gracefully), the customers.email DB column (harmless, stays).
# Safe: backups, single-match anchors w/ auto-revert, node --check, restart only the web process.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); R="$Z/.retired/$TS"; mkdir -p "$R"
cp routes/account.js "$R/account.js.bak"
revert(){ cp "$R/account.js.bak" routes/account.js; }

mkdir -p /tmp/zre/p; rm -f /tmp/zre/p/*

# ---- 1) signup: remove the optional Email field (two lines) ----
cat > /tmp/zre/p/o1 <<'OLD'
  <div class="acc-f"><label>Email <span class="opt">(optional)</span></label>
    <input type="email" name="email" value="${esc(v.email || '')}" placeholder="you@gmail.com"></div>
OLD
: > /tmp/zre/p/n1   # empty = remove

# ---- 2) signup handler: email no longer collected ----
cat > /tmp/zre/p/o2 <<'OLD'
    const email = String(b.email || '').trim().toLowerCase();
OLD
cat > /tmp/zre/p/n2 <<'NEW'
    const email = null; // email removed — WhatsApp only
NEW

# ---- 3) signup handler: drop the email-format validation ----
cat > /tmp/zre/p/o3 <<'OLD'
    if (email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return back('That email address does not look right.');
OLD
: > /tmp/zre/p/n3

# ---- 4) account page: stop selecting email ----
cat > /tmp/zre/p/o4 <<'OLD'
    try { const r = await pool.query('SELECT name, phone, email FROM customers WHERE id=$1', [c.id]); row = r.rows[0] || {}; } catch (e) {}
OLD
cat > /tmp/zre/p/n4 <<'NEW'
    try { const r = await pool.query('SELECT name, phone FROM customers WHERE id=$1', [c.id]); row = r.rows[0] || {}; } catch (e) {}
NEW

# ---- 5) account page: remove the Email row ----
cat > /tmp/zre/p/o5 <<'OLD'
    <tr><td style="color:#64748b;padding:7px 0">Email</td><td style="text-align:right">${esc(row.email || '—')}</td></tr>
OLD
: > /tmp/zre/p/n5

cat > /tmp/zre/apply.js <<'APPLY'
const fs = require('fs'); const P = '/tmp/zre/p/';
function rd(f){ try { return fs.readFileSync(f,'utf8').replace(/\n$/,''); } catch(e){ return ''; } }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); if(!o){ console.error('empty anchor '+oF); process.exit(6);} const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/account.js','o1','n1');
rep('routes/account.js','o2','n2');
rep('routes/account.js','o3','n3');
rep('routes/account.js','o4','n4');
rep('routes/account.js','o5','n5');
console.log('account.js PATCHED OK');
APPLY

node /tmp/zre/apply.js || { echo "patch failed - reverting account.js"; revert; exit 1; }
node --check routes/account.js || { echo "syntax error - reverting account.js"; revert; exit 1; }

# ---- retire the Gmail poller files (move to .retired, recoverable) ----
[ -f mailService.js ] && mv mailService.js "$R/mailService.js" && echo "retired mailService.js"
# only retire mailPoller if nothing else still requires it (zayron-mail was its only user)
if grep -rqE "require\((['\"]).*mailPoller" routes lib server.js 2>/dev/null; then
  echo "WARN: mailPoller still referenced — leaving lib/mailPoller.js in place"
else
  [ -f lib/mailPoller.js ] && mv lib/mailPoller.js "$R/mailPoller.js" && echo "retired lib/mailPoller.js"
fi

# ---- stop + delete the zayron-mail process, persist so it never resurrects ----
pm2 delete zayron-mail >/dev/null 2>&1 && echo "deleted zayron-mail process" || echo "zayron-mail already gone"
pm2 save >/dev/null 2>&1 || true

# ---- reload the web process so the signup/account changes take effect ----
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron

# ---- flag any ecosystem file that still defines zayron-mail (so it can't come back) ----
ECO=$(grep -rl "zayron-mail" "$Z"/ecosystem*.js "$Z"/*.config.js 2>/dev/null || true)
[ -n "$ECO" ] && echo "NOTE: zayron-mail still defined in: $ECO (remove that block to stop it resurrecting)"

echo "DONE: email fully removed. Backups in $R"
