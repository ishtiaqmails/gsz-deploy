#!/usr/bin/env bash
# stepZayronTrialPopupFlow — make Free Trial a one-tap desktop POPUP, never the standalone page:
#   1. any link to /trial/start opens the popup (intercepted) instead of navigating
#   2. a VERIFIED customer with no extra fields goes straight to "generating" (no Almost-there screen)
#   3. premium-up the generating view (server name + progress line)
# All in public/ztrial.js. Safe: backup, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp public/ztrial.js "$B/ztrial.js.bak"
revert(){ cp "$B/ztrial.js.bak" public/ztrial.js; pm2 restart zayron >/dev/null 2>&1 || true; }

node - <<'APPLY'
const fs=require('fs');const F='public/ztrial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('ANCHOR x'+c+': '+o.slice(0,55));process.exit(5);}s=s.split(o).join(n);}

// A1) global click: also intercept links to /trial/start -> open popup direct
rep(
`  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-ztrial]');
    if (!t) return;
    if (MASTER_OFF) {`,
`  document.addEventListener('click', function (e) {
    var t = e.target.closest('[data-ztrial]');
    var _lnk = t ? null : e.target.closest('a[href*="/trial/start"]');
    if (!t && !_lnk) return;
    var _mode, _slug;
    if (t) { _mode = t.getAttribute('data-ztrial') || 'pick'; _slug = t.getAttribute('data-slug') || ''; }
    else { _mode = 'direct'; try { _slug = (new URL(_lnk.href, location.origin)).searchParams.get('s') || ''; } catch (_e) { _slug = ''; } if (!_slug) return; }
    if (MASTER_OFF) {`);

// A2) use the computed mode/slug when opening
rep(
`    open({ mode: t.getAttribute('data-ztrial') || 'pick', slug: t.getAttribute('data-slug') || '' });
    return false;
  }, true);`,
`    open({ mode: _mode, slug: _slug });
    return false;
  }, true);`);

// B) verified + no required fields -> skip the Almost-there screen, start immediately
rep(
`      if (p) { _cameFromGrid = false; return renderFields(p); }`,
`      if (p) { _cameFromGrid = false; var _rf = (p.fields||[]).some(function(f){return f.required;}); if (VERIFIED && !_rf) return startDirect(p); return renderFields(p); }`);

// C) add startDirect + renderStarting (one-tap path)
rep(
`  function renderFields(p) {`,
`  function startDirect(p) {
    renderStarting(p);
    var params = new URLSearchParams(); params.set('s', p.slug); params.set('phone', '');
    fetch('/trial/start', { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded','X-Requested-With':'fetch','Accept':'application/json'}, body: params.toString() })
      .then(function(r){ return r.json().catch(function(){ return {}; }); })
      .then(function(d){
        if (d && d.ok === false) return renderFields(p);
        var token = (d && d.token && /^[a-f0-9]{40}$/.test(d.token)) ? d.token : null;
        if (!token) return renderFields(p);
        if (d.otp === true) { renderOtp(p, token, d.phone || ''); return; }
        renderGenerating(p, token);
      }).catch(function(){ renderFields(p); });
  }
  function renderStarting(p) {
    card().innerHTML = '<button class="zt-x">&times;</button><div class="zt-gen"><div class="zt-spin"></div><h3>Starting your trial…</h3><p>Setting things up — this will just take a moment.</p></div>';
    card().querySelector('.zt-x').addEventListener('click', close);
  }
  function renderFields(p) {`);

// D) premium-up the generating view
rep(
`      '<div class="zt-gen"><div class="zt-spin"></div>' +
      '<h3>Setting up your trial…</h3>' +
      '<p id="ztGenNote">This can take a minute or two depending on demand. Keep this window open and your login will appear here as soon as it is ready. You can also close this and come back later; we will have it waiting.</p>' + pre + _appBtns(p.apps) + '</div>';`,
`      '<div class="zt-gen"><div class="zt-spin"></div>' +
      '<h3>Setting up your ' + esc(p.name) + ' trial…</h3>' +
      '<p id="ztGenNote">This usually takes under a minute. Your login appears right here the moment it is ready — keep watching, or close this and come back; we will have it waiting.</p>' +
      '<div class="zt-count" style="margin-top:14px"><svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg> <span>Requested · Generating · Ready</span></div>' + pre + _appBtns(p.apps) + '</div>';`);

fs.writeFileSync(F,s);console.log('ztrial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; exit 1; }

node --check public/ztrial.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: Free Trial opens one-tap popup; verified users skip straight to generating. healthz=200"
