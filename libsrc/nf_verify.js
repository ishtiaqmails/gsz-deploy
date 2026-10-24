'use strict';
/* Non-invasive end-to-end verification of the Netflix code pipeline (no customer needed).
   Proves: nfMail fetch + owner_only drop + link decode on a REAL account, and tier gating
   (numeric code on Phone, change-password/household links hidden on Phone/TV, all on Full)
   on the built-in @gsztest.dev demo account.
   Run:  node /opt/gsz-deploy/libsrc/nf_verify.js /opt/gsz [realAccountEmail]  */
const R = process.argv[2] || '/opt/gsz';
const EMAIL = process.argv[3] || 'saphirenn89@outlook.com';
require(R + '/node_modules/dotenv').config({ path: R + '/.env' });
const nfMail = require(R + '/lib/nfMail');
const gate = require(R + '/lib/netflixGate');
function pass(c, m) { console.log((c ? 'PASS' : 'FAIL') + ': ' + m); if (!c) process.exitCode = 1; }
function rtypes(emails, plan) {
  const groups = {}; gate.filterEmails(emails, plan).forEach(e => { if (!groups[e.rtype]) groups[e.rtype] = e; });
  return Object.keys(groups);
}
(async () => {
  console.log('== REAL account: ' + EMAIL + ' ==');
  const m = await nfMail.listForAccount(EMAIL, true);
  pass(!!m.ok, 'nfMail fetched codes (2-step accounts -> codes)');
  console.log('   types: ' + ((m.emails || []).map(e => e.type).join(', ') || '(none)'));
  const links = (m.emails || []).map(e => e.link).filter(Boolean);
  pass(!links.some(l => /&amp;|&lt;|&gt;|&#3[89];/.test(l)), 'links fully decoded (no HTML entities left)');
  pass(links.every(l => /^https?:\/\//.test(l)), 'links are usable URLs');
  pass(!(m.emails || []).some(e => e.owner_only === true), 'no owner_only (takeover) codes present');

  console.log('\n== tier gating on built-in demo (@gsztest.dev) ==');
  const d = await nfMail.listForAccount('demo@gsztest.dev', true);
  const ph = rtypes(d.emails, 'Netflix Phone');
  const tv = rtypes(d.emails, 'Netflix TV');
  const fu = rtypes(d.emails, 'Netflix Full Account');
  console.log('   Phone shows: ' + (ph.join(', ') || '(nothing)'));
  console.log('   TV    shows: ' + (tv.join(', ') || '(nothing)'));
  console.log('   Full  shows: ' + (fu.join(', ') || '(nothing)'));
  pass(ph.indexOf('signin_code') >= 0, 'Phone shows the numeric sign-in code');
  pass(ph.indexOf('new_signin') < 0 && ph.indexOf('password_reset') < 0 && ph.indexOf('household_update') < 0, 'Phone hides household + change-password links');
  pass(tv.indexOf('household_update') >= 0 && tv.indexOf('new_signin') < 0 && tv.indexOf('password_reset') < 0, 'TV adds household link, still hides change-password');
  pass(fu.indexOf('household_update') >= 0 && fu.indexOf('password_reset') >= 0, 'Full shows household + reset links');
  console.log('\nDONE — if everything says PASS, the customer-facing code panel is correct and safe.');
})().catch(e => { console.error('ERR', e.message); process.exitCode = 1; });
