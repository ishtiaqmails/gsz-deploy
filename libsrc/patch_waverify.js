'use strict';
/* WhatsApp verification fixes on routes/whatsapp.js (idempotent):
   1) genCode -> simple 6-digit numeric code (easy for customers to type).
   2) inbound matcher accepts: "VERIFY <code>", a bare numeric code, or legacy GX- code.
   3) on VERIFIED, also set customers.wa_verified=true (the column the Hub/profile reads),
      so a verified account stops being asked to verify.
   Throws if a required change can't be anchored, so the step never half-applies. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_waverify.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/whatsapp.js');
let s = fs.readFileSync(file, 'utf8');
let applied = 0, skipped = 0; const missing = [];

// 1) numeric genCode
const GC_NEW = "function genCode() { return String(crypto.randomInt ? crypto.randomInt(100000, 1000000) : (100000 + Math.floor(Math.random() * 900000))); }";
if (s.indexOf('crypto.randomInt ? crypto.randomInt(100000') >= 0) { console.log('genCode: numeric already (skip)'); skipped++; }
else {
  const GC_RE = /function genCode\(\)\s*\{[\s\S]*?return 'GX-' \+ s;\s*\}/;
  if (GC_RE.test(s)) { s = s.replace(GC_RE, GC_NEW); console.log('genCode: -> numeric 6-digit'); applied++; }
  else missing.push('genCode');
}

// 2) broaden inbound matcher
const OLD_M = "text.match(/VERIFY\\s+([A-Z0-9-]{4,})/i)";
const NEW_M = "(text.match(/VERIFY\\s+([A-Z0-9-]{4,})/i) || text.match(/\\b(GX-[A-Z0-9]{3,})\\b/i) || text.match(/\\b(\\d{4,8})\\b/))";
if (s.indexOf("text.match(/\\b(\\d{4,8})\\b/)") >= 0) { console.log('matcher: already broadened (skip)'); skipped++; }
else if (s.indexOf(OLD_M) >= 0) {
  // only the assignment `const m = text.match(...)` — replace that first occurrence
  s = s.replace("const m = " + OLD_M + ";", "const m = " + NEW_M + ";");
  if (s.indexOf(NEW_M) >= 0) { console.log('matcher: accepts code-only + numeric + legacy'); applied++; }
  else missing.push('matcher');
} else missing.push('matcher');

// 3) set customers.wa_verified=true on VERIFIED
const VERIFIED_LINE = "await c.query(\"UPDATE whatsapp_verification_sessions SET status='VERIFIED', whatsapp_identity_id=$2, completed_at=now(), updated_at=now() WHERE id=$1\", [sess.id, identity.id]);";
if (s.indexOf("UPDATE customers SET wa_verified=true WHERE id=$1") >= 0) { console.log('wa_verified sync: already present (skip)'); skipped++; }
else if (s.indexOf(VERIFIED_LINE) >= 0) {
  s = s.replace(VERIFIED_LINE, "await c.query(\"UPDATE customers SET wa_verified=true WHERE id=$1\", [sess.customer_id]);\n      " + VERIFIED_LINE);
  console.log('wa_verified sync: customers.wa_verified set on VERIFIED'); applied++;
} else missing.push('wa_verified-sync');

if (missing.length) { console.error('PATCH FAILED — anchors not found: ' + missing.join(', ')); process.exit(2); }
if (applied) fs.writeFileSync(file, s);
console.log('WAVERIFY OK (applied ' + applied + ', skipped ' + skipped + ')');
