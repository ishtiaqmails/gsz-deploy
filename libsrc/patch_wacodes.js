'use strict';
/* patch_wacodes.js — deliver account codes over WhatsApp (in-place, idempotent).
   1) sendEmailCode: also enqueue the verification code to the customer's WhatsApp.
   2) sendResetCode: always enqueue the reset code over WhatsApp (resolves the customer's
      wa_number via customer_id even when they have no linked identity), not only for linked users.
   wanotify.enqueue({customer_id}) resolves the recipient from customers.wa_number automatically. */
const fs = require('fs');
const GSZ = '/opt/gsz';
const p = GSZ + '/routes/account.js';
let s = fs.readFileSync(p, 'utf8');
let changed = false;

/* 1) verification code via WhatsApp */
if (s.indexOf('WA_CODE_VERIFY_v1') === -1) {
  const anchor = "      `INSERT INTO customer_tokens(customer_id, kind, code, expires_at) VALUES($1,'email_verify',$2, now() + interval '30 minutes')`,\n      [c.id, code]);";
  if (s.indexOf(anchor) === -1) throw new Error('sendEmailCode token-insert anchor not found');
  const add = anchor
    + "\n    /* WA_CODE_VERIFY_v1 — deliver the verification code over WhatsApp (resolves wa_number by customer_id) */"
    + "\n    try { const _st = (await storefront.loadSettings(pool)).site_name || 'Galaxy Subz x Zayron'; await wanotify.enqueue({ customer_id: c.id, template_key: 'whatsapp.email_verify', vars: { site_name: _st, code: code }, idempotency_key: 'verify-' + c.id + '-' + code }); } catch (e) {}";
  s = s.replace(anchor, add);
  changed = true;
}

/* 2) reset code: always enqueue over WhatsApp, with or without a linked identity */
if (s.indexOf('WA_CODE_RESET_v1') === -1) {
  const anchor = "      if (link) await wanotify.enqueue({ customer_id: c.id, destination_identity_id: link.whatsapp_identity_id, template_key: 'whatsapp.password_reset', vars: { site_name: site, code: code }, idempotency_key: 'pwreset-' + c.id + '-' + code });";
  if (s.indexOf(anchor) === -1) throw new Error('sendResetCode enqueue anchor not found');
  const rep = "      /* WA_CODE_RESET_v1 — always deliver over WhatsApp (customer_id resolves wa_number even with no link) */"
    + "\n      await wanotify.enqueue({ customer_id: c.id, destination_identity_id: link ? link.whatsapp_identity_id : null, template_key: 'whatsapp.password_reset', vars: { site_name: site, code: code }, idempotency_key: 'pwreset-' + c.id + '-' + code });";
  s = s.replace(anchor, rep);
  changed = true;
}

/* 3) verify-email page: stop telling users to check email / add SMTP — codes go to WhatsApp now.
      Suppress the "Email isn't configured" note by passing mailOn:true to that view.
      Self-guarding: the original expression is gone after the replace, so re-runs are no-ops. */
{
  const a3 = "mailOn: !!(mailer && mailer.configured && mailer.configured())";
  if (s.indexOf(a3) !== -1) { s = s.split(a3).join("mailOn: true /* WhatsApp delivery */"); changed = true; }
}

if (changed) fs.writeFileSync(p, s);

/* 4) verify-email view copy: "sent to <email>" -> "sent to your WhatsApp" (guarded; skipped if absent) */
(function () {
  const vp = GSZ + '/views/account/verify_email.ejs';
  let v; try { v = fs.readFileSync(vp, 'utf8'); } catch (e) { return; }
  let vb = v;
  v = v.replace('We sent a 6-digit code to <b style="color:var(--ink)"><%= email %></b>. Enter it below to activate your account.',
                'We sent a 6-digit code to your WhatsApp. Enter it below to activate your account.');
  v = v.replace('A fresh code is on its way — check your inbox (and spam).', 'A fresh code is on its way — check your WhatsApp.');
  v = v.replace('<h1>Verify your email</h1>', '<h1>Verify your account</h1>');
  if (v !== vb) { fs.writeFileSync(vp, v); console.log('   verify_email.ejs copy updated for WhatsApp'); }
})();

console.log('PATCH ' + (changed ? 'applied' : 'already present'));
