'use strict';
/* Fix the confusing verification flow (routes/account.js):
   1) sendEmailCode no longer sends the code over WhatsApp — WhatsApp verifies ONLY by the
      customer messaging the bot (/api/whatsapp/verification/start is unchanged).
   2) signup no longer auto-sends the email code — it sends only when the customer clicks
      "Verify email" (/account/tools/email/send) or Resend.
   Indentation-independent single-line anchors, CRLF-safe, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_verifyfix.js <ROOT>'); process.exit(1); }
const AC = path.join(ROOT, 'routes/account.js');

function once(name, guard, find, replace) {
  let s = fs.readFileSync(AC, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(AC, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

// 1) drop the WhatsApp verification-code send from sendEmailCode
once('no-wa-verify-code', 'WA_CODE_VERIFY removed',
  "try { const _st = (await storefront.loadSettings(pool)).site_name || 'Galaxy Subz x Zayron'; await wanotify.enqueue({ customer_id: c.id, template_key: 'whatsapp.email_verify', vars: { site_name: _st, code: code }, idempotency_key: 'verify-' + c.id + '-' + code }); } catch (e) {}",
  "/* WA_CODE_VERIFY removed — WhatsApp verifies ONLY via the customer messaging the bot */");

// 2) don't auto-send the email code on signup
once('no-signup-verify', 'no verification sent on signup',
  "await sendEmailCode(c);",
  "/* no verification sent on signup — email code sends only when the customer clicks Verify email; WhatsApp via bot */");

console.log('VERIFYFIX OK');
