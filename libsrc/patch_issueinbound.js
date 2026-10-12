'use strict';
/* #77 Stage C — inbound WhatsApp replies into the issue thread.
   routes/whatsapp.js: in the non-code branch of /internal/whatsapp/incoming,
   if the sender is a verified customer with an OPEN issue, append their message
   to that thread, alert the owner via the Verification Bot, and acknowledge —
   otherwise fall through to the existing redirect_support reply.
   GSZ-side only (the verification bot already forwards every inbound message).
   Idempotent; aborts if the anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_issueinbound.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/whatsapp.js');
let s = fs.readFileSync(file, 'utf8');

const GUARD = "action: 'ISSUE_REPLY'";
if (s.indexOf(GUARD) >= 0) { console.log('skip (already): inbound issue reply'); process.exit(0); }

const ANCHOR = "      // Tell the owner a customer messaged the verification number (throttled 1h per sender) so we never miss them.";
const i = s.indexOf(ANCHOR);
if (i < 0) throw new Error('ANCHOR MISS: redirect-support comment');
if (s.indexOf(ANCHOR, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE');

const BLOCK =
"      // Stage C: a non-code message from a customer with an OPEN issue -> add it to that thread.\n" +
"      try {\n" +
"        const _idg = String(parts.phone || (parts.pnJid ? String(parts.pnJid).split('@')[0] : '')).replace(/[^0-9]/g, '');\n" +
"        let _cust = null;\n" +
"        if (_idg) { _cust = (await pool.query(\"SELECT c.id, c.name FROM whatsapp_identities i JOIN customer_whatsapp_links l ON l.whatsapp_identity_id=i.id AND l.status='ACTIVE' JOIN customers c ON c.id=l.customer_id WHERE regexp_replace(COALESCE(i.current_phone_e164,''),'[^0-9]','','g')=$1 LIMIT 1\", [_idg])).rows[0] || null; }\n" +
"        if (!_cust && parts.lid) { _cust = (await pool.query(\"SELECT c.id, c.name FROM whatsapp_identities i JOIN customer_whatsapp_links l ON l.whatsapp_identity_id=i.id AND l.status='ACTIVE' JOIN customers c ON c.id=l.customer_id WHERE i.lid=$1 LIMIT 1\", [parts.lid])).rows[0] || null; }\n" +
"        if (_cust && text) {\n" +
"          const _iss = (await pool.query(\"SELECT id, order_no FROM order_issues WHERE customer_id=$1 AND status='open' ORDER BY id DESC LIMIT 1\", [_cust.id])).rows[0];\n" +
"          if (_iss) {\n" +
"            await pool.query(\"INSERT INTO issue_messages(issue_id,sender,body,seen_by_admin,seen_by_customer) VALUES($1,'customer',$2,false,true)\", [_iss.id, text.slice(0, 2000)]);\n" +
"            try { const _wn = require('../lib/wanotify')(pool); String(s.wa_owner_numbers || '').split(/[,\\s]+/).map(function (x) { return x.replace(/\\D/g, '').replace(/^0/, '92'); }).filter(Boolean).forEach(function (ph) { _wn.enqueue({ destination_phone: ph, template_key: 'whatsapp.issue_owner_alert', vars: { order_no: _iss.order_no || '', customer: _cust.name || 'Customer', kind: 'Customer reply (WhatsApp)', message: text.slice(0, 500), admin_url: 'https://galaxyzayron.store/admin/issues/' + _iss.id }, idempotency_key: 'issown-wa-' + _iss.id + '-' + Math.random().toString(36).slice(2, 9) }); }); } catch (e) {}\n" +
"            return res.json({ ok: true, action: 'ISSUE_REPLY', reply: 'Thanks \\u2014 your reply has been added to your request \\u2705. Our team will respond shortly. You can also view the full conversation in your account: https://galaxyzayron.store/account' });\n" +
"          }\n" +
"        }\n" +
"      } catch (e) {}\n";

s = s.slice(0, i) + BLOCK + s.slice(i);
fs.writeFileSync(file, s);
console.log('INBOUND ISSUE-REPLY PATCH OK');
