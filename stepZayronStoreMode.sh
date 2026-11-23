#!/usr/bin/env bash
# stepZayronStoreMode — ONE master switch for zayron.tv: Manual store <-> Online store.
# Manual = WhatsApp-only, NO online traces (no Buy, no Sign-in, no account, no checkout).
# Fail-safe: any error or missing setting => MANUAL (the store can never half-break online).
# Touches: lib/storeMode.js (new), lib/paidToggle.js, lib/admin/dashboard.js, server.js.
# Safe: backups, single-match anchor guards, node --check, auto-rollback, then restart zayron.
set -e
Z=/opt/zayron
cd "$Z"
W=/tmp/zsm; rm -rf "$W"; mkdir -p "$W/p"
cp server.js "$W/server.js.bak"
cp lib/paidToggle.js "$W/paidToggle.js.bak"
cp lib/admin/dashboard.js "$W/dashboard.js.bak"
revert(){ cp "$W/server.js.bak" server.js; cp "$W/paidToggle.js.bak" lib/paidToggle.js; cp "$W/dashboard.js.bak" lib/admin/dashboard.js; rm -f lib/storeMode.js; }

# ---------- new file: lib/storeMode.js ----------
cat > lib/storeMode.js <<'STOREMODE'
// lib/storeMode.js — the single master switch for the whole store.
// store_manual = '1' -> MANUAL store: WhatsApp only, no online buying/accounts/checkout.
// store_manual = '0' -> the automated online store is live.
// Fail-safe: on ANY error, or a missing setting, we report MANUAL — the store can never
// half-break into a broken "online" state. Cached 3s like the other toggles.
const { pool } = require('../db');

let _c = { v: true, at: 0 };
const TTL = 3000;

async function storeManual() {
  if (Date.now() - _c.at < TTL) return _c.v;
  try {
    const r = await pool.query("SELECT value FROM settings WHERE key='store_manual'");
    const v = r.rows.length ? String(r.rows[0].value) === '1' : true; // default: manual
    _c = { v: v, at: Date.now() };
    return v;
  } catch (e) {
    return true; // fail-safe: manual
  }
}

// Last-known value, for synchronous template rendering (kept fresh by storeManual()).
function storeManualSync() { return _c.v !== false; }

module.exports = { storeManual, storeManualSync };
STOREMODE

# ---------- patch pairs (written literally, no shell/JS interpolation) ----------
cat > "$W/p/o1" <<'OLD'
const { isPaidLive } = require('./lib/paidToggle');
OLD
cat > "$W/p/n1" <<'NEW'
const { isPaidLive } = require('./lib/paidToggle');
const { storeManual, storeManualSync } = require('./lib/storeMode');
NEW

cat > "$W/p/o2" <<'OLD'
// ---- public site ----
app.get('/', async (req, res, next) => {
OLD
cat > "$W/p/n2" <<'NEW'
// ---- master Store Mode guard: in MANUAL mode the online store is closed ----
app.use(async (req, res, next) => {
  const p = req.path;
  if (p.startsWith('/static') || p.startsWith('/uploads') || p.startsWith('/admin') || p === '/healthz' || p.startsWith('/.well-known')) return next();
  let manual = true;
  try { manual = await storeManual(); } catch (e) { manual = true; }
  if (manual && /^\/(account|checkout|trial)(\/|$)/.test(p)) return res.redirect(302, '/contact');
  next();
});

// ---- public site ----
app.get('/', async (req, res, next) => {
NEW

cat > "$W/p/o3" <<'OLD'
    let html = TEMPLATE.replace('<!--ZAYRON_DATA-->', inject + meScriptHome);
OLD
cat > "$W/p/n3" <<'NEW'
    let html = TEMPLATE.replace('<!--ZAYRON_DATA-->', inject + meScriptHome);
    if (await storeManual()) html = html.replace('<html lang="en">', '<html lang="en" class="store-manual">');
    html = html.replace('</head>', '<style>html.store-manual .acct-btn,html.store-manual .nav-acc,html.store-manual .tools{display:none!important}</style></head>');
NEW

cat > "$W/p/o4" <<'OLD'
<!doctype html><html lang="en"${_skipIntro ? ' class="introseen"' : ''}><head><meta charset="utf-8">
OLD
cat > "$W/p/n4" <<'NEW'
<!doctype html><html lang="en" class="${_skipIntro ? 'introseen' : ''}${storeManualSync() ? ' store-manual' : ''}"><head><meta charset="utf-8">
NEW

cat > "$W/p/o5" <<'OLD'
${currentStyle()}</head><body>
OLD
cat > "$W/p/n5" <<'NEW'
${currentStyle()}<style>html.store-manual .acct-btn,html.store-manual .nav-acc,html.store-manual .tools{display:none!important}</style></head><body>
NEW

cat > "$W/p/o6" <<'OLD'
    try { const _r = await pool.query("SELECT value FROM settings WHERE key='web_players_on'"); playersLive = _r.rows[0] && String(_r.rows[0].value) === '1'; } catch (e) { playersLive = false; }
OLD
cat > "$W/p/n6" <<'NEW'
    try { const _r = await pool.query("SELECT value FROM settings WHERE key='web_players_on'"); playersLive = (_r.rows[0] && String(_r.rows[0].value) === '1') && !storeManualSync(); } catch (e) { playersLive = false; }
NEW

cat > "$W/p/o7" <<'OLD'
    const r = await pool.query("SELECT value FROM settings WHERE key='web_paid_on'");
    const on = r.rows.length ? String(r.rows[0].value) !== '0' : true;
    _masterCache = { on: on, at: Date.now() };
    return on;
OLD
cat > "$W/p/n7" <<'NEW'
    const r = await pool.query("SELECT key, value FROM settings WHERE key IN ('web_paid_on','store_manual')");
    const m = {}; r.rows.forEach(function (x) { m[x.key] = String(x.value); });
    if (m.store_manual === '1') { _masterCache = { on: false, at: Date.now() }; return false; }
    const on = ('web_paid_on' in m) ? m.web_paid_on !== '0' : true;
    _masterCache = { on: on, at: Date.now() };
    return on;
NEW

cat > "$W/p/o8" <<'OLD'
  const paidOn   = String(await getSetting('web_paid_on', '1')) !== '0';
OLD
cat > "$W/p/n8" <<'NEW'
  const paidOn   = String(await getSetting('web_paid_on', '1')) !== '0';
  const manualOn = String(await getSetting('store_manual', '1')) === '1';
NEW

cat > "$W/p/o9" <<'OLD'
    '<div class="card">' +
      '<label style="margin-top:0">Website automation</label>' +
OLD
cat > "$W/p/n9" <<'NEW'
    '<div class="card">' +
      '<label style="margin-top:0">Store mode</label>' +
      '<p class="hint" style="margin:2px 0 6px">One switch for the whole site. ON &rarr; manual WhatsApp store only &mdash; no Buy, no Sign-in, no account, no checkout, nothing online. OFF &rarr; the automated online store is live.</p>' +
      toggle('store_manual', manualOn, 'Manual store',
        'ON &rarr; whole store is manual (WhatsApp), with no trace of the online store. OFF &rarr; online store is live.') +
    '</div>' +

    '<div class="card">' +
      '<label style="margin-top:0">Website automation</label>' +
NEW

cat > "$W/p/o10" <<'OLD'
      if (key === 'web_trials_on' || key === 'web_paid_on') await setSetting(key, to);
OLD
cat > "$W/p/n10" <<'NEW'
      if (key === 'web_trials_on' || key === 'web_paid_on' || key === 'store_manual') await setSetting(key, to);
NEW

# ---------- applier ----------
cat > "$W/apply.js" <<'APPLY'
const fs = require('fs');
const P = '/tmp/zsm/p/';
function rd(f){ return fs.readFileSync(f, 'utf8').replace(/\n$/, ''); } // drop heredoc's trailing newline
function rep(file, oF, nF){
  let s = fs.readFileSync(file, 'utf8');
  const o = rd(P + oF), n = rd(P + nF);
  const c = s.split(o).length - 1;
  if (c !== 1){ console.error('ANCHOR x' + c + ' [' + oF + '] in ' + file + ': ' + o.slice(0, 60)); process.exit(5); }
  fs.writeFileSync(file, s.replace(o, function(){ return n; }));
}
rep('server.js', 'o1', 'n1');
rep('server.js', 'o2', 'n2');
rep('server.js', 'o3', 'n3');
rep('server.js', 'o4', 'n4');
rep('server.js', 'o5', 'n5');
rep('server.js', 'o6', 'n6');
rep('lib/paidToggle.js', 'o7', 'n7');
rep('lib/admin/dashboard.js', 'o8', 'n8');
rep('lib/admin/dashboard.js', 'o9', 'n9');
rep('lib/admin/dashboard.js', 'o10', 'n10');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
for f in server.js lib/paidToggle.js lib/admin/dashboard.js lib/storeMode.js; do
  node --check "$f" || { echo "syntax error in $f - reverting"; revert; exit 1; }
done

# set the switch to MANUAL so the current (off) state is clean from the first second
node -e "const {pool}=require('/opt/zayron/db');(async()=>{try{await pool.query(\"INSERT INTO settings(key,value) SELECT 'store_manual','1' WHERE NOT EXISTS (SELECT 1 FROM settings WHERE key='store_manual')\");await pool.query(\"UPDATE settings SET value='1' WHERE key='store_manual'\");console.log('store_manual = 1 (manual)');}catch(e){console.error('setting error:',e.message);}process.exit(0);})();"

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: master Store Mode switch is live and set to MANUAL (clean — no online traces)."
echo "Flip it any time in Admin dashboard -> Store mode. OFF = online store live (we wire full auto-selling next)."
