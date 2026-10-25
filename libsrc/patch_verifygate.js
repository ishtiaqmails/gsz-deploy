'use strict';
/* VERIFY_GATE_v1 — require a signed-in, WhatsApp-verified customer to place an order.
   Patches routes/checkout.js at POST /checkout and POST /cart/place.
   Admin toggle: wa_settings.require_wa_verify = 'off' disables the verify requirement
   (sign-in is ALWAYS required either way). Absent/any other value = required (default ON).
   EOL-aware (CRLF or LF), idempotent, throws if any anchor is missing so it never half-applies. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const file = path.join(ROOT, 'routes/checkout.js');
let s = fs.readFileSync(file, 'utf8');
const EOL = s.indexOf('\r\n') >= 0 ? '\r\n' : '\n';

if (s.indexOf('VERIFY_GATE_v1') >= 0) { console.log('VERIFY_GATE_v1 already present — skip'); process.exit(0); }

function gate(pageExpr) {
  return "      /* VERIFY_GATE_v1 — must be signed in + WhatsApp-verified to order */" + EOL
    + "      if (!(req.session && req.session.customer)) return res.redirect('/login?next=' + encodeURIComponent(" + pageExpr + "));" + EOL
    + "      try { const _rq = (await pool.query(\"SELECT value FROM wa_settings WHERE key='require_wa_verify'\")).rows[0]; if (!(_rq && String(_rq.value) === 'off')) { const _vr = (await pool.query('SELECT wa_verified FROM customers WHERE id=$1', [req.session.customer.id])).rows[0]; if (!_vr || !_vr.wa_verified) return res.redirect((" + pageExpr + ") + ((" + pageExpr + ").indexOf('?') >= 0 ? '&' : '?') + 'e=' + encodeURIComponent('Please verify your WhatsApp from your account before ordering \\u2014 open your account and tap \\u201cVerify your WhatsApp\\u201d.')); } } catch (e) {}" + EOL;
}

const applied = [];

// POST /checkout — insert after the `const fail = ...` that follows this handler's unique `back` line.
{
  const backAnchor = "const back = '/checkout?p='";
  const bi = s.indexOf(backAnchor);
  if (bi < 0) throw new Error('checkout back-anchor not found');
  const failIdx = s.indexOf('const fail = msg =>', bi);
  if (failIdx < 0) throw new Error('checkout fail-anchor not found after back');
  const nl = s.indexOf('\n', failIdx);
  if (nl < 0) throw new Error('checkout fail line-end not found');
  const at = nl + 1;
  s = s.slice(0, at) + gate('back') + s.slice(at);
  applied.push('/checkout');
}

// POST /cart/place — insert right after its `const _sccart = ...` line.
{
  const anchor = "const _sccart = (req.session && req.session.customer) ? req.session.customer : null;";
  const ai = s.indexOf(anchor);
  if (ai < 0) throw new Error('cart _sccart anchor not found');
  const nl = s.indexOf('\n', ai);
  if (nl < 0) throw new Error('cart _sccart line-end not found');
  const at = nl + 1;
  s = s.slice(0, at) + gate("'/cart'") + s.slice(at);
  applied.push('/cart/place');
}

fs.writeFileSync(file, s);
console.log('VERIFY_GATE_v1 applied to: ' + applied.join(', '));
