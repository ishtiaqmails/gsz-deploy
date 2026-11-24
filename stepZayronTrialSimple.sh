#!/usr/bin/env bash
# stepZayronTrialSimple — make the trial system SIMPLE:
#   - Admin "Trials > Rules" becomes one table: Server | Free trial on/off | Bot status | Trials per customer.
#     (bot status auto-syncs via the bridge; if the bot turns a panel's trial off it shows "off in bot".)
#   - Enforcement becomes a plain per-server count: a customer gets N trials per server (trial_config.trial_limit),
#     no cooldowns / providers / tiers. Duration still comes from the bot.
# Safe: backups, full rewrite of lib/admin/trials.js + anchored edits to trial.js & admin.js, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zts; rm -rf "$W"; mkdir -p "$W/p"
cp lib/admin/trials.js "$W/trials.js.bak"
cp routes/trial.js "$W/trialroute.js.bak"
cp routes/admin.js "$W/admin.js.bak"
revert(){ cp "$W/trials.js.bak" lib/admin/trials.js; cp "$W/trialroute.js.bak" routes/trial.js; cp "$W/admin.js.bak" routes/admin.js; }

# ---------- 1) new lib/admin/trials.js (simple) ----------
cat > lib/admin/trials.js <<'TRIALS'
// lib/admin/trials.js — simple trial admin: per server, on/off + how many trials a customer gets.
// Availability also auto-syncs with the bot (bridge product.trial.enabled).
const { pool, getSetting } = require('../../db');

function e(v) {
  return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) {
    return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
  });
}
function tabs(active) {
  const t = function (href, label, on) {
    return '<a href="' + href + '" style="padding:9px 16px;border-radius:10px;font-size:13.5px;font-weight:700;text-decoration:none;' +
      (on ? 'background:#0047FF;color:#fff' : 'background:#fff;color:var(--ink);border:1px solid var(--line)') + '">' + label + '</a>';
  };
  return '<div style="display:flex;gap:8px;margin-bottom:18px">' +
    t('/admin/trials', 'Signups', active === 'signups') +
    t('/admin/trials/rules', 'Free trials', active === 'rules') +
  '</div>';
}

async function rulesPage(req) {
  const master = String(await getSetting('web_trials_on', '1')) !== '0';
  const flash = req.query.ok ? '<div class="flash">Saved.</div>' : '';
  let rows = [];
  try {
    rows = (await pool.query(
      'SELECT s.id, s.name, s.trial, s.bot_sku, c.trial_limit ' +
      'FROM servers s LEFT JOIN trial_config c ON c.server_id = s.id ' +
      'WHERE s.active = true ORDER BY s.sort, s.name')).rows;
  } catch (err) { rows = []; }

  let botState = {};
  try {
    const tt = require('../trialToggle');
    for (const r of rows) { botState[r.id] = r.bot_sku ? !(await tt.isTrialDisabled(r.bot_sku)) : null; }
  } catch (err) { botState = {}; }

  const th = 'padding:11px 12px;font-size:12px;color:#475569;border-bottom:1px solid #e6ebf3;font-weight:700';
  const tdB = 'padding:11px 12px;border-bottom:1px solid #f1f5f9';
  const body = rows.map(function (r) {
    const on = !!r.trial;
    const bot = botState[r.id];
    const botTxt = (bot === null || bot === undefined)
      ? '<span class="muted" style="font-size:11.5px">not mapped</span>'
      : (bot ? '<span style="color:#00A650;font-weight:700;font-size:12px">ready</span>'
             : '<span style="color:#c2410c;font-weight:700;font-size:12px">off in bot</span>');
    const lim = (r.trial_limit != null && +r.trial_limit > 0) ? +r.trial_limit : 1;
    return '<tr' + (on ? '' : ' style="opacity:.6"') + '>' +
      '<td style="' + tdB + '"><input type="hidden" name="row_' + r.id + '" value="1"><b>' + e(r.name) + '</b></td>' +
      '<td style="' + tdB + ';text-align:center"><label style="display:inline-flex;align-items:center;gap:6px;cursor:pointer;font-size:12px;font-weight:700"><input type="checkbox" name="on_' + r.id + '" value="1"' + (on ? ' checked' : '') + '>' + (on ? 'On' : 'Off') + '</label></td>' +
      '<td style="' + tdB + ';text-align:center">' + botTxt + '</td>' +
      '<td style="' + tdB + ';text-align:center"><input name="lim_' + r.id + '" type="number" min="1" value="' + lim + '" style="width:70px;padding:7px 8px;font-size:13px;text-align:center;border:1px solid var(--line);border-radius:7px"></td>' +
    '</tr>';
  }).join('');

  const masterWarn = master ? ''
    : '<div class="card" style="border-color:#f6d68a;background:#fffaf0"><b>Free trials are off site-wide.</b> <span class="muted">Trial buttons open WhatsApp instead. Turn them on from the <a href="/admin">Dashboard</a>.</span></div>';

  return flash +
    '<h1>Free trials</h1><p class="sub">Turn the trial on per server and set how many each customer gets. Availability also follows the bot automatically — if a panel’s trial is off in the bot it shows here and hides on the site.</p>' +
    tabs('rules') + masterWarn +
    '<form method="post" action="/admin/trials/servers"><div class="card" style="padding:0;overflow:hidden">' +
    '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:13px;min-width:520px">' +
    '<thead><tr style="background:#f8fafc">' +
    '<th style="' + th + ';text-align:left">Server</th>' +
    '<th style="' + th + ';text-align:center">Free trial</th>' +
    '<th style="' + th + ';text-align:center">Bot</th>' +
    '<th style="' + th + ';text-align:center">Trials per customer</th>' +
    '</tr></thead><tbody>' + (body || '<tr><td colspan="4" style="padding:18px;text-align:center" class="muted">No servers yet.</td></tr>') + '</tbody></table></div>' +
    '<div style="padding:14px 16px"><button class="btn" type="submit">Save</button></div>' +
    '</div></form>';
}

function register(router, deps) {
  router.get('/trials/rules', async (req, res, next) => {
    try { res.send(deps.layout('Free trials', await rulesPage(req), '/admin/trials')); }
    catch (err) { next(err); }
  });
  router.post('/trials/servers', async (req, res, next) => {
    try {
      const b = req.body || {};
      const ids = [];
      for (const k in b) { const m = k.match(/^row_(\d+)$/); if (m) ids.push(Number(m[1])); }
      for (const id of ids) {
        const on = !!b['on_' + id];
        await pool.query('UPDATE servers SET trial=$1 WHERE id=$2', [on, id]);
        let lim = parseInt(b['lim_' + id], 10); if (!Number.isFinite(lim) || lim < 1) lim = 1;
        await pool.query(
          'INSERT INTO trial_config (server_id, trial_limit, updated_at) VALUES ($1,$2,now()) ' +
          'ON CONFLICT (server_id) DO UPDATE SET trial_limit=$2, updated_at=now()',
          [id, lim]);
      }
      res.redirect('/admin/trials/rules?ok=1');
    } catch (err) { next(err); }
  });
}

module.exports = { rulesPage, register, tabs };
TRIALS
node --check lib/admin/trials.js || { echo "trials.js syntax err"; revert; exit 1; }

# ---------- 2) trial.js: replace the tangled limit logic with a per-server count ----------
cat > "$W/p/o1" <<'OLD'
      const cd = await cooldownDays(s.id);

      const _isFetchEarly = (req.get('X-Requested-With') === 'fetch') || (req.get('Accept') || '').indexOf('application/json') >= 0;
      // ANTI-ABUSE: same phone OR same ip already claimed this server within cooldown window
      if (cd > 0) {
        const _tierCd = await trialTier.resolve(req);
        const _cdUse = Math.min(Number(cd)||30, _tierCd.cooldownDays);
        const dup = await pool.query(
          `SELECT created_at FROM trials
             WHERE server_id=$1 AND status<>'expired'
               AND (phone=$2 OR ip=$3)
               AND created_at > now() - ($4 || ' days')::interval
             ORDER BY created_at DESC LIMIT 1`,
          [s.id, phone, ip, String(_cdUse)]);
        if (dup.rows.length) {
          const next = new Date(new Date(dup.rows[0].created_at).getTime() + cd * 864e5);
          const when = next.toISOString().slice(0, 10);
          if (_isFetchEarly) return res.json({ ok: false, reason: 'used', when: when, provider: s.n });
          return page(res, data, 'Trial already used — Zayron',
            `<div style="text-align:center"><h1 style="font-size:24px">You've already used your free trial for ${escAttr(s.n)}</h1>
             <p class="sec-p">One free trial per person, per server. You can request another after <b>${when}</b>.</p>
             <a class="btn white" href="/server/${escAttr(s.slug)}">Back to ${escAttr(s.n)}</a></div>`);
        }
      }

      const _tier = await trialTier.resolve(req);
      const _maxP = _tier.maxProviders;
      if (_maxP > 0) {
        const _usedIds = await _usedProviders(req, s.id);
        const _alreadyThis = (await pool.query("SELECT 1 FROM trials WHERE server_id=$1 AND status<>'expired' AND (ip=$2 OR claim_token=$3) LIMIT 1", [s.id, clientIp(req), (req.cookies && req.cookies['zt_tok_' + String(s.slug).replace(/[^a-z0-9_]/gi,'')]) || ''])).rows.length > 0;
        if (!_alreadyThis && _usedIds.length >= _maxP) {
          if (_isFetchEarly) return res.json({ ok: false, reason: 'maxed', limit: _maxP, used: _usedIds.length });
          return page(res, data, 'Trial limit reached — Zayron',
            '<div style="text-align:center"><h1 style="font-size:24px">You have used all your free trials</h1>' +
            '<p class="sec-p">You can try up to ' + _maxP + ' providers, and you have used ' + _usedIds.length + '. Message us on WhatsApp to continue.</p>' +
            '<a class="btn white" href="/">Back to home</a></div>');
        }
      }
OLD
cat > "$W/p/n1" <<'NEW'
      const _isFetchEarly = (req.get('X-Requested-With') === 'fetch') || (req.get('Accept') || '').indexOf('application/json') >= 0;
      // SIMPLE RULE: each customer gets a fixed number of trials per server (trial_config.trial_limit, default 1).
      let _maxTrials = 1;
      try { const _lc = await pool.query('SELECT trial_limit FROM trial_config WHERE server_id=$1', [s.id]); if (_lc.rows.length && Number.isFinite(+_lc.rows[0].trial_limit) && +_lc.rows[0].trial_limit > 0) _maxTrials = +_lc.rows[0].trial_limit; } catch (e) {}
      const _tok = (req.cookies && req.cookies['zt_tok_' + String(s.slug).replace(/[^a-z0-9_]/gi, '')]) || '';
      let _usedN = 0;
      try {
        _usedN = (await pool.query(
          "SELECT COUNT(*)::int n FROM trials WHERE server_id=$1 AND (phone=$2 OR ip=$3" + (_tok ? " OR claim_token=$4" : "") + ")",
          _tok ? [s.id, phone, ip, _tok] : [s.id, phone, ip])).rows[0].n;
      } catch (e) { _usedN = 0; }
      if (_usedN >= _maxTrials) {
        if (_isFetchEarly) return res.json({ ok: false, reason: 'used', limit: _maxTrials, used: _usedN, provider: s.n });
        return page(res, data, 'Trial already used — Zayron',
          `<div style="text-align:center"><h1 style="font-size:24px">You've used your free trial${_maxTrials > 1 ? 's' : ''} for ${escAttr(s.n)}</h1>
           <p class="sec-p">${_maxTrials > 1 ? ('Up to ' + _maxTrials + ' free trials per person on this server.') : 'One free trial per person on this server.'} Message us on WhatsApp to continue.</p>
           <a class="btn white" href="/server/${escAttr(s.slug)}">Back to ${escAttr(s.n)}</a></div>`);
      }
NEW

# ---------- 3) admin.js: server-edit trial card copy ----------
cat > "$W/p/o2" <<'OLD'
      <div class="card" style="background:#f4f8ff;border-color:#c7d6f2;margin-bottom:14px"><b>Trial limits</b><div class="muted" style="font-size:12.5px;margin-top:3px">How long the trial lasts, how many servers a person may try and how long they wait are all set together on the <a href="/admin/trials/rules"><b>Trials page</b></a>.</div></div>
OLD
cat > "$W/p/n2" <<'NEW'
      <div class="card" style="background:#f4f8ff;border-color:#c7d6f2;margin-bottom:14px"><b>Free trial</b><div class="muted" style="font-size:12.5px;margin-top:3px">Turn the trial on and set how many each customer gets on the <a href="/admin/trials/rules"><b>Free trials</b></a> page. Duration comes from the bot automatically.</div></div>
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zts/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+'] in '+file); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/trial.js','o1','n1');
rep('routes/admin.js','o2','n2');
console.log('PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
for f in routes/trial.js routes/admin.js; do node --check "$f" || { echo "syntax error $f - reverting"; revert; exit 1; }; done

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: trial admin + rules simplified to per-server 'trials per customer', auto-synced with the bot."
