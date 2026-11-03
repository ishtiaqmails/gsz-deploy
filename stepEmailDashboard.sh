#!/usr/bin/env bash
# Email Senders dashboard: route + page + sidebar link + server mount.
# Backs up everything, validates, auto-reverts on any failure. Safe to paste-and-run.
cd /opt/gsz
TS=$(date +%s)
ROUTE=/opt/gsz/routes/adminEmail.js
VIEW=/opt/gsz/views/admin/email.ejs
SRV=/opt/gsz/server.js
SHELL=/opt/gsz/views/admin/_shell_top.ejs
cp "$SRV" "$SRV.bak.$TS"
cp "$SHELL" "$SHELL.bak.$TS"
[ -f "$ROUTE" ] && cp "$ROUTE" "$ROUTE.bak.$TS"
[ -f "$VIEW" ] && cp "$VIEW" "$VIEW.bak.$TS"

cat > "$ROUTE" <<'ROUTEEOF'
const express = require('express');
module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '1mb' });
  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }
  let mailer = null; try { mailer = require('../lib/mailer'); } catch (e) { mailer = null; }
  const TYPES = ['brevo', 'zeptomail', 'resend'];
  function refresh() { try { if (mailer && mailer.refresh) mailer.refresh(); } catch (e) {} }
  const back = (res, kind, msg) => res.redirect('/admin/email?' + kind + '=' + encodeURIComponent(msg));

  router.get('/email', auth, async (req, res) => {
    const rows = (await pool.query("SELECT id,label,provider,from_name,from_email,region,is_active,last_status,last_tested_at FROM email_providers ORDER BY is_active DESC, id")).rows;
    res.render('admin/email', { rows, active: 'email', title: 'Email Senders', flash: req.query.ok || null, err: req.query.err || null, editId: req.query.edit ? (parseInt(req.query.edit, 10) || 0) : 0 });
  });

  router.post('/email/add', auth, body, async (req, res) => {
    try {
      const b = req.body || {};
      const provider = TYPES.indexOf(String(b.provider || '').trim()) >= 0 ? String(b.provider).trim() : 'brevo';
      const api_key = String(b.api_key || '').trim();
      const from_email = String(b.from_email || '').trim();
      if (!api_key || !from_email) return back(res, 'err', 'API key and From email are required');
      await pool.query("INSERT INTO email_providers(label,provider,api_key,from_name,from_email,region,is_active) VALUES($1,$2,$3,$4,$5,$6,false)",
        [String(b.label || '').trim() || provider, provider, api_key, String(b.from_name || '').trim(), from_email, String(b.region || '').trim()]);
      refresh(); back(res, 'ok', 'Sender added');
    } catch (e) { back(res, 'err', 'Add failed: ' + e.message); }
  });

  router.post('/email/:id/edit', auth, body, async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10) || 0; const b = req.body || {};
      const provider = TYPES.indexOf(String(b.provider || '').trim()) >= 0 ? String(b.provider).trim() : 'brevo';
      const from_email = String(b.from_email || '').trim();
      if (!from_email) return back(res, 'err', 'From email is required');
      const label = String(b.label || '').trim() || provider, from_name = String(b.from_name || '').trim(), region = String(b.region || '').trim(), api_key = String(b.api_key || '').trim();
      if (api_key) await pool.query("UPDATE email_providers SET label=$1,provider=$2,from_name=$3,from_email=$4,region=$5,api_key=$6,updated_at=now() WHERE id=$7", [label, provider, from_name, from_email, region, api_key, id]);
      else await pool.query("UPDATE email_providers SET label=$1,provider=$2,from_name=$3,from_email=$4,region=$5,updated_at=now() WHERE id=$6", [label, provider, from_name, from_email, region, id]);
      refresh(); back(res, 'ok', 'Sender updated');
    } catch (e) { back(res, 'err', 'Update failed: ' + e.message); }
  });

  router.post('/email/:id/activate', auth, async (req, res) => {
    const id = parseInt(req.params.id, 10) || 0; const c = await pool.connect();
    try {
      await c.query('BEGIN');
      await c.query("UPDATE email_providers SET is_active=false WHERE is_active=true");
      await c.query("UPDATE email_providers SET is_active=true, updated_at=now() WHERE id=$1", [id]);
      await c.query('COMMIT'); refresh(); back(res, 'ok', 'Active sender switched');
    } catch (e) { try { await c.query('ROLLBACK'); } catch (x) {} back(res, 'err', 'Activate failed: ' + e.message); }
    finally { c.release(); }
  });

  router.post('/email/:id/delete', auth, async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10) || 0;
      const row = (await pool.query("SELECT is_active FROM email_providers WHERE id=$1", [id])).rows[0];
      await pool.query("DELETE FROM email_providers WHERE id=$1", [id]);
      if (row && row.is_active) { const n = (await pool.query("SELECT id FROM email_providers ORDER BY id LIMIT 1")).rows[0]; if (n) await pool.query("UPDATE email_providers SET is_active=true WHERE id=$1", [n.id]); }
      refresh(); back(res, 'ok', 'Sender removed');
    } catch (e) { back(res, 'err', 'Delete failed: ' + e.message); }
  });

  router.post('/email/:id/test', auth, body, async (req, res) => {
    try {
      const id = parseInt(req.params.id, 10) || 0;
      const to = String((req.body && req.body.to) || '').trim();
      if (!to) return back(res, 'err', 'Enter a test recipient email');
      const p = (await pool.query("SELECT id,provider,api_key,from_name,from_email,region FROM email_providers WHERE id=$1", [id])).rows[0];
      if (!p) return back(res, 'err', 'Sender not found');
      if (!mailer || !mailer.sendWith) return back(res, 'err', 'Mail engine unavailable');
      const html = '<div style="font-family:system-ui,Segoe UI,Arial,sans-serif;padding:16px"><h2 style="margin:0 0 8px">Test email</h2><p>This is a test from your Galaxy Subz x Zayron admin. If you received it, this sender works.</p><p style="color:#667">Service: ' + p.provider + ' &middot; From: ' + p.from_email + '</p></div>';
      try {
        await mailer.sendWith(p, to, 'Test email from Galaxy Subz x Zayron', html);
        await pool.query("UPDATE email_providers SET last_status='ok (test)', last_tested_at=now() WHERE id=$1", [id]);
        back(res, 'ok', 'Test sent to ' + to);
      } catch (e) {
        await pool.query("UPDATE email_providers SET last_status=$1, last_tested_at=now() WHERE id=$2", [String(e.message).slice(0, 240), id]);
        back(res, 'err', 'Test failed: ' + String(e.message).slice(0, 160));
      }
    } catch (e) { back(res, 'err', 'Test failed: ' + e.message); }
  });

  return router;
};
ROUTEEOF

cat > "$VIEW" <<'VIEWEOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title><%= title || 'Email Senders' %></title>
<style>
  :root{--bg:#f4f6fb;--card:#fff;--ink:#121a2e;--muted:#6b7280;--hair:#e6e9f2;--brand:#2a7bff;--brand2:#6a5cff;--ok:#16935c;--okbg:#e7f6ee;--danger:#b42318;--dangerbg:#fdeaea}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif}
  a{color:var(--brand);text-decoration:none}
  .wrap{max-width:860px;margin:0 auto;padding:18px 16px 64px}
  .top{display:flex;align-items:center;gap:12px;margin-bottom:16px;flex-wrap:wrap}
  .top h1{font-size:20px;margin:0;font-weight:800;letter-spacing:-.01em}
  .top .sp{flex:1}
  .lnk{display:inline-flex;align-items:center;gap:6px;font-weight:600;font-size:13.5px;color:var(--muted)}
  .btn{display:inline-flex;align-items:center;justify-content:center;gap:6px;border:1px solid var(--hair);background:#fff;color:var(--ink);border-radius:10px;padding:9px 14px;font:inherit;font-size:13.5px;font-weight:700;cursor:pointer;text-decoration:none}
  .btn:hover{border-color:#cfd6e6}
  .btn-p{background:linear-gradient(90deg,var(--brand),var(--brand2));border-color:transparent;color:#fff}
  .btn-d{color:var(--danger)}
  .btn-sm{padding:7px 11px;font-size:12.5px}
  .flash{padding:11px 14px;border-radius:12px;font-size:13.5px;font-weight:600;margin-bottom:16px}
  .flash.ok{background:var(--okbg);color:var(--ok)}
  .flash.err{background:var(--dangerbg);color:var(--danger)}
  .intro{font-size:13.5px;color:#39415c;margin:0 0 6px}
  .card{background:var(--card);border:1px solid var(--hair);border-radius:16px;padding:16px 18px;margin-bottom:14px;box-shadow:0 1px 2px rgba(15,24,54,.04)}
  .sec-h{font-size:12px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin:22px 2px 10px}
  .nm{font-weight:800;font-size:16px;display:flex;align-items:center;gap:9px;flex-wrap:wrap}
  .tag{font-size:11px;font-weight:800;padding:3px 9px;border-radius:999px;background:#eef2fb;color:#49527a;text-transform:uppercase;letter-spacing:.03em}
  .badge-active{background:var(--okbg);color:var(--ok)}
  .meta{color:var(--muted);font-size:13px;margin-top:3px;word-break:break-word}
  .status{font-size:12.5px;margin-top:6px}
  .status.ok{color:var(--ok)}.status.bad{color:var(--danger)}
  .acts{display:flex;gap:7px;flex-wrap:wrap;align-items:center}
  form.inline{display:flex;gap:7px;flex-wrap:wrap;align-items:center;margin:0}
  input,select{font:inherit;font-size:14px;border:1px solid var(--hair);border-radius:10px;padding:9px 11px;background:#fff;color:var(--ink);width:100%}
  input:focus,select:focus{outline:none;border-color:var(--brand)}
  .grid{display:grid;grid-template-columns:1fr 1fr;gap:12px}
  .fld{display:flex;flex-direction:column;gap:5px}
  .fld label{font-size:12.5px;font-weight:700;color:#49527a}
  .fld .h{font-size:11.5px;color:var(--muted);font-weight:500}
  .full{grid-column:1 / -1}
  .test-in{max-width:230px}
  .guide{font-size:13.5px;color:#39415c}
  .guide h4{margin:14px 0 5px;font-size:14px}
  .guide ol{margin:4px 0 0;padding-left:20px}
  .guide li{margin:3px 0}
  .guide code{background:#eef2fb;padding:1px 6px;border-radius:6px;font-size:12.5px}
  @media(max-width:560px){ .grid{grid-template-columns:1fr} .test-in{max-width:100%} }
</style>
</head>
<body>
<div class="wrap">
  <div class="top">
    <h1>Email Senders</h1>
    <div class="sp"></div>
    <a class="lnk" href="/admin">&larr; Dashboard</a>
    <form method="post" action="/admin/logout" style="margin:0"><button class="btn btn-sm" type="submit">Log out</button></form>
  </div>

  <% if (flash) { %><div class="flash ok"><%= flash %></div><% } %>
  <% if (err) { %><div class="flash err"><%= err %></div><% } %>

  <p class="intro">These services send order &amp; account emails to your customers. The one marked <b>Active</b> is used right now. Add a service, press <b>Set active</b>, and the next email uses it &mdash; no coding.</p>

  <div class="sec-h">Your senders</div>
  <% if (!rows.length) { %><div class="card"><div class="meta">No senders yet. Add one below.</div></div><% } %>
  <% rows.forEach(function(r){ var editing = (editId===r.id); %>
    <div class="card">
      <% if (!editing) { %>
        <div class="nm"><%= r.label || r.provider %> <span class="tag"><%= r.provider %></span><% if (r.is_active) { %> <span class="tag badge-active">Active</span><% } %></div>
        <div class="meta">From: <%= r.from_name ? (r.from_name + ' ') : '' %>&lt;<%= r.from_email %>&gt;</div>
        <% if (r.last_status) { %><div class="status <%= /^ok/i.test(r.last_status)?'ok':'bad' %>">Last check: <%= r.last_status %></div><% } %>
        <div class="acts" style="margin-top:12px">
          <% if (!r.is_active) { %><form method="post" action="/admin/email/<%= r.id %>/activate" class="inline"><button class="btn btn-p btn-sm" type="submit">Set active</button></form><% } %>
          <form method="post" action="/admin/email/<%= r.id %>/test" class="inline"><input class="test-in" type="email" name="to" placeholder="test email address" required><button class="btn btn-sm" type="submit">Send test</button></form>
          <a class="btn btn-sm" href="/admin/email?edit=<%= r.id %>">Edit</a>
          <form method="post" action="/admin/email/<%= r.id %>/delete" class="inline" onsubmit="return confirm('Remove this sender?')"><button class="btn btn-sm btn-d" type="submit">Delete</button></form>
        </div>
      <% } else { %>
        <form method="post" action="/admin/email/<%= r.id %>/edit">
          <div class="grid">
            <div class="fld"><label>Name (your label)</label><input name="label" value="<%= r.label %>" placeholder="e.g. Zoho ZeptoMail"></div>
            <div class="fld"><label>Service</label><select name="provider"><option value="brevo"<%= r.provider==='brevo'?' selected':'' %>>Brevo</option><option value="zeptomail"<%= r.provider==='zeptomail'?' selected':'' %>>Zoho ZeptoMail</option><option value="resend"<%= r.provider==='resend'?' selected':'' %>>Resend</option></select></div>
            <div class="fld"><label>From name</label><input name="from_name" value="<%= r.from_name %>" placeholder="Galaxy Subz x Zayron"></div>
            <div class="fld"><label>From email</label><input name="from_email" type="email" value="<%= r.from_email %>" required></div>
            <div class="fld full"><label>API key / token</label><input name="api_key" placeholder="Leave blank to keep the current key"><span class="h">Only type here to replace the saved key.</span></div>
            <div class="fld"><label>Region (ZeptoMail only)</label><input name="region" value="<%= r.region %>" placeholder="blank = .com, or in / eu"></div>
          </div>
          <div class="acts" style="margin-top:12px"><button class="btn btn-p btn-sm" type="submit">Save changes</button><a class="btn btn-sm" href="/admin/email">Cancel</a></div>
        </form>
      <% } %>
    </div>
  <% }); %>

  <div class="sec-h">Add a sender</div>
  <div class="card">
    <form method="post" action="/admin/email/add">
      <div class="grid">
        <div class="fld"><label>Name (your label)</label><input name="label" placeholder="e.g. Zoho ZeptoMail"></div>
        <div class="fld"><label>Service</label><select name="provider"><option value="zeptomail">Zoho ZeptoMail</option><option value="brevo">Brevo</option><option value="resend">Resend</option></select></div>
        <div class="fld"><label>From name</label><input name="from_name" placeholder="Galaxy Subz x Zayron"></div>
        <div class="fld"><label>From email</label><input name="from_email" type="email" required placeholder="orders@galaxyzayron.store"></div>
        <div class="fld full"><label>API key / token</label><input name="api_key" required placeholder="Paste the service API key or token"></div>
        <div class="fld"><label>Region (ZeptoMail only)</label><input name="region" placeholder="blank = .com, or in / eu"></div>
      </div>
      <div class="acts" style="margin-top:12px"><button class="btn btn-p btn-sm" type="submit">Add sender</button></div>
    </form>
  </div>

  <div class="sec-h">Setup guide</div>
  <div class="card guide">
    <p style="margin:0">All three send over an internet API (your server blocks the old email ports), so they work here. Your domain <b>galaxyzayron.store</b> must be verified in the service you choose (add one DKIM DNS record) so mail reaches inbox, not spam.</p>
    <h4>Zoho ZeptoMail (recommended &mdash; matches your Zoho domain)</h4>
    <ol>
      <li>Sign in at <code>zeptomail.zoho.com</code> and add your domain <code>galaxyzayron.store</code>.</li>
      <li>Add the DKIM / SPF DNS records it shows, then verify.</li>
      <li>Create a <b>Send Mail Token</b> and paste it here as the API key.</li>
      <li>From email must be on the verified domain. Region: blank for .com, or <code>in</code> / <code>eu</code>.</li>
    </ol>
    <h4>Brevo</h4>
    <ol>
      <li>In Brevo: <b>SMTP &amp; API &rarr; API Keys</b>, create a key, paste here.</li>
      <li>Authenticate <code>galaxyzayron.store</code> under <b>Senders, Domains &amp; Dedicated IPs</b> (add their SPF + DKIM records).</li>
    </ol>
    <h4>Resend</h4>
    <ol>
      <li>At <code>resend.com</code>, add &amp; verify your domain (add the DNS records it lists).</li>
      <li>Create an API key (starts with <code>re_</code>) and paste here.</li>
    </ol>
  </div>
</div>
</body>
</html>
VIEWEOF

node <<'NODEEOF'
const fs = require('fs');
const SRV = '/opt/gsz/server.js', SHELL = '/opt/gsz/views/admin/_shell_top.ejs';
let s = fs.readFileSync(SRV, 'utf8');
const anchor = "app.use('/admin', adminIssuesRouter);";
if (s.indexOf('adminEmailRouter') >= 0) { console.log('server.js: already mounted'); }
else if (s.split(anchor).length - 1 === 1) {
  s = s.replace(anchor, anchor + "\ntry { const adminEmailRouter = require('./routes/adminEmail')(pool); app.use('/admin', adminEmailRouter); } catch (e) { console.error('adminEmail mount failed:', e.message); }");
  fs.writeFileSync(SRV, s); console.log('server.js: mounted adminEmail');
} else { console.log('WARN server.js anchor count=' + (s.split(anchor).length - 1) + '; mount NOT added'); }
let h = fs.readFileSync(SHELL, 'utf8');
const navAnchor = '<a href="/admin/maintenance"';
if (h.indexOf('/admin/email') >= 0) { console.log('nav: email link already present'); }
else if (h.split(navAnchor).length - 1 >= 1) {
  const link = '<a href="/admin/email" class="<%= on(\'email\') %>"><svg viewBox="0 0 24 24"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>Email Senders</a>\n    ';
  h = h.replace(navAnchor, link + navAnchor); fs.writeFileSync(SHELL, h); console.log('nav: Email Senders link added');
} else { console.log('WARN nav anchor not found; link NOT added (page still at /admin/email)'); }
NODEEOF

OK=1
node -c "$ROUTE" || OK=0
node -c "$SRV" || OK=0
node -e "const ejs=require('/opt/gsz/node_modules/ejs');const fs=require('fs');ejs.compile(fs.readFileSync('$VIEW','utf8'));" || OK=0

if [ "$OK" = "1" ]; then
  echo "VALIDATION OK"
  pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"
  sleep 2
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3900/admin/email || echo ERR)
  echo "GET /admin/email -> HTTP $code  (302 = mounted, needs admin login; 404 = not mounted)"
else
  echo "VALIDATION FAILED -> reverting all changes"
  cp "$SRV.bak.$TS" "$SRV"
  cp "$SHELL.bak.$TS" "$SHELL"
  rm -f "$ROUTE" "$VIEW"
  echo "reverted; site unchanged"
fi
echo "backups tagged .bak.$TS"
echo DONE
