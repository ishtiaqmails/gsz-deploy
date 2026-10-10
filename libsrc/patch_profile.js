'use strict';
/* Deploy B backend (added to routes/account.js):
   - GET  /account/tools/profile   -> customer details (name, email+verified, wa+verified, member since, ref)
   - POST /account/tools/profile   -> update one field (name | wa | email); changing email/wa resets its verified flag
   - GET  /api/announcements       -> public: recent global announcements for the ticker
   Idempotent (skips if already present). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_profile.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/account/tools/profile') >= 0) { console.log('skip (already): profile endpoints present'); console.log('PROFILE PATCH OK'); process.exit(0); }

const ROUTES =
"  // ---- PROFILE (Hub: My Account) ----\n" +
"  router.get('/account/tools/profile', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; let p=null;\n" +
"    try{ p=(await pool.query(\"SELECT name, email, email_verified, wa_number, wa_verified, created_at, ref_code FROM customers WHERE id=$1\",[c.id])).rows[0]; }catch(e){}\n" +
"    if(!p) return res.json({ ok:false });\n" +
"    res.json({ ok:true, profile:{ name:p.name||'', email:p.email||'', email_verified:!!p.email_verified, wa_number:p.wa_number||'', wa_verified:!!p.wa_verified, member_since:p.created_at, ref_code:p.ref_code||'' } });\n" +
"  });\n" +
"  router.post('/account/tools/profile', express.json({limit:'8kb'}), requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const b=req.body||{}; const field=String(b.field||''); const value=String(b.value||'').trim();\n" +
"    try{\n" +
"      if(field==='name'){ if(!value) return res.json({ ok:false, error:'Please enter your name.' }); const v=value.slice(0,80); await pool.query(\"UPDATE customers SET name=$1 WHERE id=$2\",[v,c.id]); try{ req.session.customer.name=v; }catch(e){} return res.json({ ok:true, field:'name', value:v }); }\n" +
"      if(field==='wa'){ const d=value.replace(/[^0-9]/g,''); if(d.length<8) return res.json({ ok:false, error:'Enter a valid WhatsApp number with country code.' }); await pool.query(\"UPDATE customers SET wa_number=$1, wa_verified=false WHERE id=$2\",[d,c.id]); return res.json({ ok:true, field:'wa', value:d, verified:false }); }\n" +
"      if(field==='email'){ const em=value.toLowerCase(); if(!/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(em)) return res.json({ ok:false, error:'Enter a valid email address.' }); const ex=(await pool.query(\"SELECT id FROM customers WHERE lower(email)=lower($1) AND id<>$2 LIMIT 1\",[em,c.id])).rows[0]; if(ex) return res.json({ ok:false, error:'That email is already in use.' }); await pool.query(\"UPDATE customers SET email=$1, email_verified=false WHERE id=$2\",[em,c.id]); try{ req.session.customer.email=em; }catch(e){} return res.json({ ok:true, field:'email', value:em, verified:false }); }\n" +
"      return res.json({ ok:false, error:'Nothing to update.' });\n" +
"    }catch(e){ res.json({ ok:false, error:'Could not update right now.' }); }\n" +
"  });\n" +
"  router.get('/api/announcements', async (req, res) => {\n" +
"    let rows=[];\n" +
"    try{ rows=(await pool.query(\"SELECT id, title, body, kind, coupon_code FROM announcements WHERE target_product_id IS NULL ORDER BY id DESC LIMIT 8\")).rows; }catch(e){}\n" +
"    res.json({ ok:true, items: rows.map(function(a){ return { id:a.id, title:a.title, body:a.body, kind:a.kind||'', coupon:a.coupon_code||'' }; }) });\n" +
"  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/tools/profile (GET/POST) + /api/announcements');
console.log('PROFILE PATCH OK');
