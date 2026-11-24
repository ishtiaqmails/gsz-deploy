#!/usr/bin/env bash
# stepZayronTrialPageReconcile — the standalone trial page never polled /status, so it spun forever even
# though the bridge had the trial ready. Add a shared _reconcileTrial(token) and call it on the hold page
# load (and keep it for /status), so the page completes on its own. Also fix getProducts() to return the
# products ARRAY (the bridge returns { ok, products:[...] }), which was throwing ".find is not a function".
# Safe: backup both files, single-match anchors + auto-revert, node --check, 12s healthz.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"
cp routes/trial.js "$B/trial.js.bak"; cp lib/gszApi.js "$B/gszApi.js.bak"
revert(){ cp "$B/trial.js.bak" routes/trial.js; cp "$B/gszApi.js.bak" lib/gszApi.js; pm2 restart zayron >/dev/null 2>&1 || true; }

# --- 1) gszApi.getProducts -> return the array ---
node - <<'APPLY'
const fs=require('fs');const F='lib/gszApi.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('GSZAPI ANCHOR x'+c);process.exit(5);}s=s.split(o).join(n);}
rep(
`async function getProducts() {
  const hit = cget('prod'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/products', null, 8000);
  return cset('prod', j, TTL.prod);
}`,
`async function getProducts() {
  const hit = cget('prod'); if (hit !== undefined) return hit;
  const j = await req('GET', '/api/products', null, 8000);
  const arr = (j && Array.isArray(j.products)) ? j.products : (Array.isArray(j) ? j : []);
  return cset('prod', arr, TTL.prod);
}`);
fs.writeFileSync(F,s);console.log('gszApi.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "gszApi.js patch failed"; exit 1; }

# --- 2) trial.js: add _reconcileTrial helper + call it on the hold page ---
node - <<'APPLY'
const fs=require('fs');const F='routes/trial.js';let s=fs.readFileSync(F,'utf8');
function rep(o,n){const c=s.split(o).length-1;if(c!==1){console.error('TRIAL ANCHOR x'+c+': '+o.slice(0,50));process.exit(5);}s=s.split(o).join(n);}

// a) define the shared reconcile helper (polls bridge, flips row, delivers once)
rep(
`  const express = require('express');`,
`  async function _reconcileTrial(token) {
    const r = await pool.query('SELECT * FROM trials WHERE claim_token=$1', [token]);
    if (!r.rows.length) return { ok: false };
    const t = r.rows[0];
    if (t.status === 'ready' || t.status === 'expired') {
      return { ok: true, status: t.status, user: t.line_user, pass: t.line_pass, url: t.line_url, expires_at: (t.expires_at ? new Date(t.expires_at).toISOString() : null) };
    }
    if (t.bot_job_id) {
      const p = await pollWebTrial(token);
      if (p && p.status === 'done' && p.result) {
        const u = p.result.username || null, pw = p.result.password || null;
        const url = p.result.host || p.result.m3u || null;
        let hrs = 24;
        try { const c = await pool.query('SELECT trial_hours FROM trial_config WHERE server_id=$1', [t.server_id]); if (c.rows.length && Number.isFinite(+c.rows[0].trial_hours)) hrs = +c.rows[0].trial_hours; } catch (e) {}
        const _flip = await pool.query("UPDATE trials SET status='ready', line_user=$1, line_pass=$2, line_url=$3, ready_at=now(), expires_at=now() + ($4 || ' hours')::interval WHERE id=$5 AND status<>'ready'", [u, pw, url, String(hrs), t.id]);
        if (_flip.rowCount && t.phone) {
          try {
            const _nl = String.fromCharCode(10);
            let _body = (p.result.formatted && String(p.result.formatted).trim()) ? String(p.result.formatted).trim() : '';
            if (!_body) { const _L = ['Your Zayron free trial is ready.']; if (u) _L.push('Username: ' + u); if (pw) _L.push('Password: ' + pw); if (url) _L.push('URL: ' + url); _body = _L.join(_nl); }
            if (_body.toLowerCase().indexOf('zayron.tv') < 0) _body = _body + _nl + _nl + 'www.zayron.tv';
            await pool.query("INSERT INTO otp_outbox (phone, body, status) VALUES ($1,$2,'queued')", [t.phone, _body]);
          } catch (e) {}
        }
        return { ok: true, status: 'ready', user: u, pass: pw, url: url, formatted: p.result.formatted || null, expires_at: new Date(Date.now() + hrs*3600*1000).toISOString() };
      }
      if (p && p.status === 'failed') { await pool.query("UPDATE trials SET status='failed' WHERE id=$1 AND status<>'ready'", [t.id]); return { ok: true, status: 'failed' }; }
    }
    return { ok: true, status: 'pending' };
  }
  const express = require('express');`);

// b) the hold page reconciles on load, so it completes by itself
rep(
`      const data = await getPublicData();
      const r = await pool.query('SELECT * FROM trials WHERE claim_token=$1', [token]);`,
`      const data = await getPublicData();
      try { await _reconcileTrial(token); } catch (e) {}
      const r = await pool.query('SELECT * FROM trials WHERE claim_token=$1', [token]);`);

fs.writeFileSync(F,s);console.log('trial.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "trial.js patch failed - reverting"; revert; exit 1; }

node --check lib/gszApi.js || { echo "gszApi syntax error - reverting"; revert; exit 1; }
node --check routes/trial.js || { echo "trial syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: trial page now reconciles itself (no infinite spinner) + getProducts returns an array. healthz=200"
