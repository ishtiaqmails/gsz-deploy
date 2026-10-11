'use strict';
/* Add ajax email-verification endpoints for the in-Hub flow (routes/account.js), reusing the
   existing sendEmailCode() + customer_tokens(kind='email_verify') logic:
     POST /account/tools/email/send   -> emails a fresh 6-digit code, {ok,sent,email,already}
     POST /account/tools/email/verify -> checks the code, sets email_verified, {ok} / {ok:false,error}
   Injected before the FORGOT/RESET anchor. Idempotent; hard-fails if the anchor is missing. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_emailverify.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');
if (s.indexOf('/account/tools/email/verify') >= 0) { console.log('email-verify: already present (skip)'); console.log('EMAILVERIFY OK'); process.exit(0); }

const ROUTE =
  "  // ---- EMAIL VERIFICATION (in-Hub, ajax) ----\n" +
  "  router.post('/account/tools/email/send', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer;\n" +
  "    try{ const full=(await pool.query('SELECT * FROM customers WHERE id=$1',[c.id])).rows[0];\n" +
  "      if(!full) return res.json({ ok:false, error:'account' });\n" +
  "      if(full.email_verified) return res.json({ ok:true, already:true });\n" +
  "      const mailOn = await sendEmailCode(full);\n" +
  "      return res.json({ ok:true, sent:!!mailOn, email:full.email||'' });\n" +
  "    }catch(e){ return res.json({ ok:false, error:'Could not send the code. Please try again.' }); }\n" +
  "  });\n" +
  "  router.post('/account/tools/email/verify', body, requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; const code=String((req.body&&req.body.code)||'').replace(/[^0-9]/g,'');\n" +
  "    if(code.length!==6) return res.json({ ok:false, error:'Enter the 6-digit code from your email.' });\n" +
  "    try{\n" +
  "      const t=(await pool.query(\"SELECT * FROM customer_tokens WHERE customer_id=$1 AND kind='email_verify' AND used=false AND expires_at > now() ORDER BY id DESC LIMIT 1\",[c.id])).rows[0];\n" +
  "      if(!t) return res.json({ ok:false, error:'That code has expired. Tap Resend for a new one.' });\n" +
  "      if(t.tries>=6) return res.json({ ok:false, error:'Too many attempts. Tap Resend for a fresh code.' });\n" +
  "      if(String(t.code)!==code){ await pool.query('UPDATE customer_tokens SET tries=COALESCE(tries,0)+1 WHERE id=$1',[t.id]); return res.json({ ok:false, error:'That code is not correct. Please check and try again.' }); }\n" +
  "      await pool.query('UPDATE customer_tokens SET used=true WHERE id=$1',[t.id]);\n" +
  "      await pool.query('UPDATE customers SET email_verified=true WHERE id=$1',[c.id]);\n" +
  "      try{ req.session.customer.email_verified=true; }catch(e){}\n" +
  "      return res.json({ ok:true });\n" +
  "    }catch(e){ return res.json({ ok:false, error:'Could not verify right now. Please try again.' }); }\n" +
  "  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) { console.error('PATCH FAILED — FORGOT/RESET anchor not found'); process.exit(2); }
s = s.slice(0, i) + ROUTE + s.slice(i);
fs.writeFileSync(file, s);
console.log('EMAILVERIFY OK');
