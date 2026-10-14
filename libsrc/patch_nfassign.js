'use strict';
/* Netflix auto-assign at delivery (lib/deliver.js) — whitespace/line-ending robust.
   On an nf_enabled order marked delivered with no typed creds:
     - Profile plan (source=inventory): atomically claim a free nf_account for the plan and
       create its nf_assignment (tier from plan nf_tier/derived, expiry from plan duration).
     - Full plan (source=portal): nfPortal.assign() provisions from the Portal; store it locally
       as nf_account + nf_assignment so the code panel lights up.
   Generic (non-Netflix) delivery is untouched (guarded by nfHandled).
   Matches are anchored on content that is independent of indentation. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_nfassign.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'lib/deliver.js');
let s = fs.readFileSync(file, 'utf8');

// exact single replace with guard + uniqueness
function once(name, guard, find, replace) {
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + replace + s.slice(i + find.length);
  console.log('patched: ' + name);
}

const HELPERS =
"  function nfAddDuration(val, unit) {\n" +
"    const n = parseInt(val, 10) || 0; const u = String(unit || '').toLowerCase(); const d = new Date();\n" +
"    if (!n) { d.setDate(d.getDate() + 30); return d; }\n" +
"    if (/month/.test(u)) d.setMonth(d.getMonth() + n);\n" +
"    else if (/year/.test(u)) d.setFullYear(d.getFullYear() + n);\n" +
"    else if (/week/.test(u)) d.setDate(d.getDate() + n * 7);\n" +
"    else d.setDate(d.getDate() + n);\n" +
"    return d;\n" +
"  }\n" +
"  async function nfAssign(cur, orderId) {\n" +
"    const pl = (await pool.query(\"SELECT id, source, nf_portal_product_id, nf_tier, duration_value, duration_unit FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1\", [cur.product_id, cur.plan_label])).rows[0];\n" +
"    if (!pl) return '';\n" +
"    const tier = (['phone', 'tv', 'full'].indexOf(pl.nf_tier) >= 0) ? pl.nf_tier : (nfGate ? nfGate.tierForPlan(cur.plan_label) : 'phone');\n" +
"    const exp = nfAddDuration(pl.duration_value, pl.duration_unit);\n" +
"    if (pl.source === 'portal' && pl.nf_portal_product_id && nfPortal.configured()) {\n" +
"      const days = Math.max(1, Math.round((exp.getTime() - Date.now()) / 86400000));\n" +
"      const r = await nfPortal.assign({ productId: pl.nf_portal_product_id, buyerName: (String(cur.email || 'Customer').split('@')[0]) || 'Customer', buyerWhatsApp: String(cur.whatsapp || '').replace(/[^0-9]/g, ''), days: days });\n" +
"      if (!r || !r.ok) return '';\n" +
"      const email = r.assignedEmail || '';\n" +
"      const credsObj = { email: email, password: r.password || '', profile: '', pin: '' };\n" +
"      const accIns = await pool.query(\"INSERT INTO nf_accounts(account_email, credentials, product_id, status, plan_id, note) VALUES($1,$2,$3,'active',$4,$5) RETURNING id\", [email, JSON.stringify(credsObj), cur.product_id, pl.id, 'portal-assigned ' + cur.order_no]);\n" +
"      await pool.query(\"INSERT INTO nf_assignments(nf_account_id, order_id, order_no, customer_id, plan_tier, status, expires_at) VALUES($1,$2,$3,$4,$5,'active',$6)\", [accIns.rows[0].id, orderId, cur.order_no, cur.customer_id || null, tier, exp]);\n" +
"      return 'Netflix account (full)\\nLogin page: ' + (r.portalUrl || '') + '\\nUsername: ' + (r.username || email) + '\\nPassword: ' + (r.password || '') + '\\nAccount email: ' + email;\n" +
"    }\n" +
"    const claim = (await pool.query(\"INSERT INTO nf_assignments(nf_account_id, order_id, order_no, customer_id, plan_tier, status, expires_at) SELECT a.id, $2, $3, $4, $5, 'active', $6 FROM nf_accounts a WHERE a.plan_id=$1 AND a.status='active' AND NOT EXISTS (SELECT 1 FROM nf_assignments x WHERE x.nf_account_id=a.id AND x.status='active') ORDER BY a.id LIMIT 1 RETURNING nf_account_id\", [pl.id, orderId, cur.order_no, cur.customer_id || null, tier, exp])).rows[0];\n" +
"    if (!claim) return '';\n" +
"    const acc = (await pool.query(\"SELECT account_email, credentials FROM nf_accounts WHERE id=$1\", [claim.nf_account_id])).rows[0] || {};\n" +
"    let cr = acc.credentials || {}; if (typeof cr === 'string') { try { cr = JSON.parse(cr); } catch (e) { cr = {}; } }\n" +
"    const email = cr.email || acc.account_email || '';\n" +
"    const lines = ['Netflix (profile)'];\n" +
"    if (email) lines.push('Email: ' + email);\n" +
"    if (cr.password) lines.push('Password: ' + cr.password);\n" +
"    if (cr.profile) lines.push('Profile: ' + cr.profile);\n" +
"    if (cr.pin) lines.push('PIN: ' + cr.pin);\n" +
"    return lines.join('\\n');\n" +
"  }\n\n";

// 1) require netflixGate
once('require-netflixGate', "require('./netflixGate')",
  "let nfPortal = null; try { nfPortal = require('./nfPortal'); } catch (e) { nfPortal = { configured: () => false, assign: async () => ({ ok: false }) }; }",
  "let nfPortal = null; try { nfPortal = require('./nfPortal'); } catch (e) { nfPortal = { configured: () => false, assign: async () => ({ ok: false }) }; }\nlet nfGate = null; try { nfGate = require('./netflixGate'); } catch (e) { nfGate = null; }");

// 2) helpers before markDelivered
once('helpers', 'async function nfAssign(cur, orderId)',
  "  async function markDelivered(orderId, opts) {",
  HELPERS + "  async function markDelivered(orderId, opts) {");

// 3) order SELECT: add customer_id
once('cur-customer_id', "whatsapp, order_no, customer_id FROM orders",
  "SELECT status, product_id, plan_label, email, whatsapp, order_no FROM orders WHERE id=$1",
  "SELECT status, product_id, plan_label, email, whatsapp, order_no, customer_id FROM orders WHERE id=$1");

// 4) guard BOTH existing delivery branches on the condition text (indentation-independent)
if (s.indexOf('!nfHandled && !creds') >= 0) {
  console.log('skip (already): nfHandled guard');
} else {
  const parts = s.split('(!creds && !wasDelivered');
  const n = parts.length - 1;
  if (n < 2) throw new Error('GUARD: expected >=2 "(!creds && !wasDelivered" sites, found ' + n);
  s = parts.join('(!nfHandled && !creds && !wasDelivered');
  console.log('patched: nfHandled guard (' + n + ' sites)');
}

// 5) declare nfHandled + the Netflix branch, right after the wasDelivered line
if (s.indexOf('let nfHandled = false;') >= 0) {
  console.log('skip (already): nf-branch');
} else {
  const anchor = "const wasDelivered = cur.status === 'delivered';";
  const i = s.indexOf(anchor);
  if (i < 0) throw new Error('ANCHOR MISS: nf-branch (wasDelivered line)');
  if (s.indexOf(anchor, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: nf-branch');
  const NFBRANCH =
    "\n    let nfHandled = false;\n" +
    "    if (!creds && !wasDelivered) {\n" +
    "      try {\n" +
    "        const _nf = (await pool.query('SELECT nf_enabled FROM products WHERE id=$1', [cur.product_id])).rows[0];\n" +
    "        if (_nf && _nf.nf_enabled) { nfHandled = true; creds = (await nfAssign(cur, orderId)) || ''; }\n" +
    "      } catch (e) {}\n" +
    "    }";
  const at = i + anchor.length;
  s = s.slice(0, at) + NFBRANCH + s.slice(at);
  console.log('patched: nf-branch');
}

fs.writeFileSync(file, s);
console.log('NFASSIGN PATCH OK');
