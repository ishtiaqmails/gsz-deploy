#!/usr/bin/env bash
# stepZayronAccountTrials — the account Trials tab now lists each trial and reveals its login
# (username / password / URL) on click, with a time-left pill and copy buttons. Pending trials link
# to their status page. (Paid orders already show credentials in the Subscriptions tab.)
# File-based anchor (template literals safe). Safe: backup, single-match + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/account.js "$B/account.js.bak"
revert(){ cp "$B/account.js.bak" routes/account.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
  router.get('/trials', requireLogin, async (req, res) => {
    const c = me(req);
    let rows = [];
    try {
      const r = await pool.query(
        "SELECT t.status, t.line_user, t.expires_at, s.name AS server FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE right(regexp_replace(t.phone,'[^0-9]','','g'),10) = right(regexp_replace($1,'[^0-9]','','g'),10) ORDER BY t.id DESC LIMIT 20",
        [c.phone]);
      rows = r.rows;
    } catch (e) {}
    const inner = rows.length
      ? `<div class="za-card"><p class="za-hd">My trials</p>${rows.map(r => `
        <div style="display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid #eef2fa;font-size:13.5px">
          <span>${esc(r.server || 'Trial')}</span>
          <span style="color:${r.status === 'ready' ? '#16a34a' : '#64748b'};font-size:12.5px">${esc(r.status)}</span>
        </div>`).join('')}</div>`
      : `<div class="za-empty"><b>No trials yet</b>Try any server free before you buy.<a class="za-cta" href="/">Start a free trial</a></div>`;
    res.send(shellPage('My trials — Zayron', dashPage(c, 'trials', inner), await deps.getPublicData(), { noindex: true }));
  });
O

cat > "$T/n" <<'O'
  router.get('/trials', requireLogin, async (req, res) => {
    const c = me(req);
    let rows = [];
    try {
      const r = await pool.query(
        "SELECT t.status, t.line_user, t.line_pass, t.line_url, t.expires_at, t.claim_token, s.name AS server, s.slug AS slug FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE right(regexp_replace(t.phone,'[^0-9]','','g'),10) = right(regexp_replace($1,'[^0-9]','','g'),10) ORDER BY t.id DESC LIMIT 20",
        [c.phone]);
      rows = r.rows;
    } catch (e) {}
    const leftStr = function (d) { if (!d) return ''; const ms = new Date(d).getTime() - Date.now(); if (ms <= 0) return 'Expired'; const h = Math.floor(ms / 3600000), m = Math.floor((ms % 3600000) / 60000); return h + 'h ' + m + 'm left'; };
    const items = rows.map(function (r, i) {
      const expired = r.expires_at && new Date(r.expires_at) < new Date();
      const ready = r.status === 'ready' && r.line_user && !expired;
      const pill = expired ? '<span class="za-pill bad">Expired</span>'
        : ready ? '<span class="za-pill ok">' + esc(leftStr(r.expires_at)) + '</span>'
        : r.status === 'failed' ? '<span class="za-pill bad">Failed</span>'
        : '<span class="za-pill warn">Setting up</span>';
      let body = '';
      if (ready) {
        body = '<div class="zt-ac-b" id="ztb' + i + '" hidden><div class="za-creds">' +
          '<div class="za-cred"><span>Username</span><b>' + esc(r.line_user) + '</b><button class="za-cp" data-c="' + esc(r.line_user) + '">Copy</button></div>' +
          (r.line_pass ? '<div class="za-cred"><span>Password</span><b>' + esc(r.line_pass) + '</b><button class="za-cp" data-c="' + esc(r.line_pass) + '">Copy</button></div>' : '') +
          (r.line_url ? '<div class="za-cred"><span>DNS / URL</span><b class="mono">' + esc(r.line_url) + '</b><button class="za-cp" data-c="' + esc(r.line_url) + '">Copy</button></div>' : '') +
          '</div></div>';
      } else if (!expired && r.status !== 'failed' && r.claim_token) {
        body = '<div class="zt-ac-b"><a class="za-btn ghost" href="/trial/' + esc(r.claim_token) + '">Open status page</a></div>';
      }
      const toggle = ready ? '<span class="zt-ac-x">View login ▾</span>' : '';
      return '<div class="zt-ac"><div class="zt-ac-h"' + (ready ? ' data-i="' + i + '"' : '') + '><div class="zt-ac-nm"><b>' + esc(r.server || 'Trial') + '</b></div>' + pill + toggle + '</div>' + body + '</div>';
    }).join('');
    const inner = rows.length
      ? '<div class="za-card"><p class="za-hd">My trials</p>' + items + '</div>' +
        '<style>.zt-ac{border-bottom:1px solid #eef2fa}.zt-ac:last-child{border-bottom:none}.zt-ac-h{display:flex;align-items:center;gap:10px;padding:12px 0}.zt-ac-h[data-i]{cursor:pointer}.zt-ac-nm{flex:1;font-size:13.5px}.zt-ac-x{font-size:12px;color:#0047FF;font-weight:700;white-space:nowrap}.zt-ac-b{padding:0 0 12px}</style>' +
        '<script>(function(){document.querySelectorAll(".zt-ac-h[data-i]").forEach(function(h){h.addEventListener("click",function(){var b=document.getElementById("ztb"+h.getAttribute("data-i"));if(b)b.hidden=!b.hidden;});});document.querySelectorAll(".za-cp").forEach(function(b){b.addEventListener("click",function(){try{navigator.clipboard.writeText(b.getAttribute("data-c"));var o=b.textContent;b.textContent="Copied";setTimeout(function(){b.textContent=o;},1200);}catch(e){}});});})();</script>'
      : '<div class="za-empty"><b>No trials yet</b>Try any server free before you buy.<a class="za-cta" href="/">Start a free trial</a></div>';
    res.send(shellPage('My trials — Zayron', dashPage(c, 'trials', inner), await deps.getPublicData(), { noindex: true }));
  });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2]; const F='routes/account.js';
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync(F,'utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync(F, s.split(O).join(N)); console.log('account.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: Trials tab reveals login on click with a time-left pill. healthz=200"
