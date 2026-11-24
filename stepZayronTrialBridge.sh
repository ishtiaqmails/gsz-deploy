#!/usr/bin/env bash
# stepZayronTrialBridge — move SITE trials onto the gsz-api bridge (was the dead 10.104.0.2 DB):
#   - lib/botQueue.js fully replaced: enqueueWebTrial -> gszApi.generateTrial (sku=server.bot_sku,
#     request_id=trial claim token), pollWebTrial -> gszApi.trialStatus (parses the line out). No DB creds.
#   - routes/trial.js: pass bot_sku + token at enqueue; store bot_job_id=1 (submitted flag);
#     status route polls by the claim token.
#   - trial OTP verification turned ON (otp_status.otp_enabled=1) so trials verify before a free line.
# Site-trials stay OFF (web_trials_on=0) until you flip them. Safe: backups, anchors+auto-revert, check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/ztb; rm -rf "$W"; mkdir -p "$W/p"
cp lib/botQueue.js "$W/botQueue.js.bak"
cp routes/trial.js "$W/trial.js.bak"
revert(){ cp "$W/botQueue.js.bak" lib/botQueue.js; cp "$W/trial.js.bak" routes/trial.js; }

# ---------- 1) new lib/botQueue.js (bridge, no DB) ----------
cat > lib/botQueue.js <<'BQ'
// lib/botQueue.js — zayron web-trial bridge via gsz-api (generate-trial / trial-status).
// No direct DB, no credentials. request_id = the trial's claim token (unique per trial).
const gszApi = require('./gszApi');

// Enqueue a web trial. sku = server.bot_sku, requestId = trial claim token.
// Returns 1 on success (job tracked by requestId), null on failure/not-supported.
async function enqueueWebTrial(sku, requestId) {
  try {
    if (!sku || !requestId) return null;
    const r = await gszApi.generateTrial({ sku: sku, request_id: String(requestId), customer_ref: 'zayron-web' });
    if (r && r.ok !== false && r.status !== 'failed') return 1;
    return null;
  } catch (e) { return null; }
}

// Poll by requestId (the claim token). Returns { status, result:{username,password,host,m3u,formatted} } or null.
async function pollWebTrial(requestId) {
  try {
    const st = await gszApi.trialStatus(String(requestId));
    if (!st || st.ok === false) return null;
    if (st.status !== 'done') return { status: (st.status === 'failed' ? 'failed' : (st.status || 'pending')), result: null, error: st.error || null };
    const out = { username: null, password: null, host: null, m3u: null, formatted: st.credentials || null };
    const details = (st.fields && Array.isArray(st.fields.details)) ? st.fields.details : [];
    details.forEach(function (d) {
      const l = String(d.label || '').toLowerCase(), v = String(d.value || '');
      if (!v) return;
      if (/user|login/.test(l) && !out.username) out.username = v;
      else if (/pass/.test(l) && !out.password) out.password = v;
      else if (/m3u/.test(l) && !out.m3u) out.m3u = v;
      else if (/(url|dns|server|host|portal|link)/.test(l) && !out.host) out.host = v;
    });
    if ((!out.username || !out.password || !out.host) && st.credentials) {
      const txt = String(st.credentials);
      if (!out.username) { const m = txt.match(/user(?:name)?\s*[:=]\s*([^\s\n]+)/i); if (m) out.username = m[1]; }
      if (!out.password) { const m = txt.match(/pass(?:word)?\s*[:=]\s*([^\s\n]+)/i); if (m) out.password = m[1]; }
      if (!out.host) { const m = txt.match(/(?:dns|url|server|host)[\s:=]*?(https?:\/\/[^\s\n]+)/i); if (m) out.host = m[1]; }
    }
    return { status: 'done', result: out };
  } catch (e) { return null; }
}

module.exports = { enqueueWebTrial, pollWebTrial };
BQ
node --check lib/botQueue.js || { echo "botQueue syntax error - reverting"; revert; exit 1; }

# ---------- 2) trial.js: start enqueue uses bot_sku + token ----------
cat > "$W/p/o1" <<'OLD'
      if (s.reseller_pid) {
        try {
          const _jobId = await enqueueWebTrial(s.reseller_pid, '');
          if (_jobId) await pool.query('UPDATE trials SET bot_job_id=$1 WHERE id=$2', [_jobId, _trialRowId]);
        } catch (e) {}
      }
OLD
cat > "$W/p/n1" <<'NEW'
      try {
        const _bs = (await pool.query('SELECT bot_sku FROM servers WHERE id=$1', [s.id])).rows[0];
        if (_bs && _bs.bot_sku) {
          const _ok = await enqueueWebTrial(_bs.bot_sku, token);
          if (_ok) await pool.query('UPDATE trials SET bot_job_id=1 WHERE id=$1', [_trialRowId]);
        }
      } catch (e) {}
NEW

# ---------- 3) trial.js: verify SELECT also pulls bot_sku ----------
cat > "$W/p/o2" <<'OLD'
      const r = await pool.query('SELECT t.id, t.otp_code, t.otp_expires, t.server_id, s.reseller_pid FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE t.claim_token=$1', [token]);
OLD
cat > "$W/p/n2" <<'NEW'
      const r = await pool.query('SELECT t.id, t.otp_code, t.otp_expires, t.server_id, s.reseller_pid, s.bot_sku FROM trials t LEFT JOIN servers s ON s.id=t.server_id WHERE t.claim_token=$1', [token]);
NEW

# ---------- 4) trial.js: verify enqueue uses bot_sku + token ----------
cat > "$W/p/o3" <<'OLD'
      if (t.reseller_pid) {
        try {
          const _jobId = await enqueueWebTrial(t.reseller_pid, '');
          if (_jobId) await pool.query('UPDATE trials SET bot_job_id=$1 WHERE id=$2', [_jobId, t.id]);
        } catch (e) {}
      }
OLD
cat > "$W/p/n3" <<'NEW'
      if (t.bot_sku) {
        try {
          const _ok = await enqueueWebTrial(t.bot_sku, token);
          if (_ok) await pool.query('UPDATE trials SET bot_job_id=1 WHERE id=$1', [t.id]);
        } catch (e) {}
      }
NEW

# ---------- 5) trial.js: status route polls by the claim token ----------
cat > "$W/p/o4" <<'OLD'
        const p = await pollWebTrial(t.bot_job_id);
OLD
cat > "$W/p/n4" <<'NEW'
        const p = await pollWebTrial(req.params.token);
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/ztb/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/trial.js','o1','n1');
rep('routes/trial.js','o2','n2');
rep('routes/trial.js','o3','n3');
rep('routes/trial.js','o4','n4');
console.log('trial.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check routes/trial.js || { echo "syntax error - reverting"; revert; exit 1; }

# turn ON trial OTP verification (flow already exists; this is its gate)
node -e "const{pool}=require('./db');pool.query(\"INSERT INTO otp_status(k,v,updated_at) VALUES('otp_enabled','1',now()) ON CONFLICT (k) DO UPDATE SET v='1', updated_at=now()\").then(()=>{console.log('trial OTP verification = ON');process.exit(0)}).catch(e=>{console.log('otp_enabled err',e.message);process.exit(0)})"

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: site-trials now provision through the bridge + require WhatsApp verification. web_trials_on still 0 — flip it when ready."
