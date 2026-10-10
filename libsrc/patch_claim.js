'use strict';
/* CLAIM / REPLACE (customer side), added to routes/account.js:
   - replaces the old JSON /account/tools/claim with a multipart handler (screenshot upload),
     warranty-gated eligibility (delivered + under warranty), one-open-claim-per-order guard.
   - GET  /account/tools/claims         -> this customer's requests + admin decision/response/new creds
   - GET  /account/tools/issue-file/:id -> streams the admin's attached screenshot (ownership-checked)
   Screenshots live in <app>/uploads and are served only through auth routes (never a public mount). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_claim.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const OLD =
  "  router.post('/account/tools/claim', express.json({limit:'16kb'}), requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; const b = req.body||{};\n" +
  "    const orderNo=String(b.order_no||'').trim(); const reason=String(b.reason||'').trim().slice(0,80); const message=String(b.message||'').trim().slice(0,1000);\n" +
  "    if(!orderNo || !message) return res.json({ ok:false, error:'Please choose an order and describe the issue.' });\n" +
  "    try{\n" +
  "      const o=(await pool.query(\"SELECT id, order_no FROM orders WHERE order_no=$1 AND (customer_id=$2 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($3))) LIMIT 1\",[orderNo,c.id,c.email])).rows[0];\n" +
  "      if(!o) return res.json({ ok:false, error:'We could not match that order to your account.' });\n" +
  "      const ins=await pool.query(\"INSERT INTO order_issues(order_id, customer_id, kind, message, order_no, status, customer_email) VALUES($1,$2,$3,$4,$5,'open',$6) RETURNING id\",[o.id, c.id, (reason||'Replacement'), message, o.order_no, c.email||null]);\n" +
  "      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'issue', type:'issue', order_no:o.order_no, issue_id:ins.rows[0].id, message:('['+(reason||'Replacement')+'] '+message).slice(0,500) }); } }catch(e){}\n" +
  "      res.json({ ok:true });\n" +
  "    }catch(e){ res.json({ ok:false, error:'Could not submit. Please try again.' }); }\n" +
  "  });\n";

const NEW =
  "  // ---- CLAIM / REPLACE (screenshot upload + warranty-gated) ----\n" +
  "  const _clP = require('path'), _clFs = require('fs');\n" +
  "  const _clDir = _clP.join(__dirname, '..', 'uploads');\n" +
  "  try { _clFs.mkdirSync(_clDir, { recursive: true }); } catch (e) {}\n" +
  "  const _clMul = require('multer')({\n" +
  "    storage: require('multer').diskStorage({\n" +
  "      destination: function (q, f, cb) { cb(null, _clDir); },\n" +
  "      filename: function (q, f, cb) { var e=(String(f.originalname||'').match(/\\.[a-z0-9]+$/i)||['.png'])[0]; cb(null, 'claim-'+Date.now()+'-'+Math.random().toString(36).slice(2,8)+e.toLowerCase()); }\n" +
  "    }),\n" +
  "    limits: { fileSize: 12 * 1024 * 1024 },\n" +
  "    fileFilter: function (q, f, cb) { cb(null, /\\.(png|jpe?g|webp|gif|heic|heif|pdf)$/i.test(f.originalname || '')); }\n" +
  "  });\n" +
  "  function _clDur(label){ var x=String(label||'').toLowerCase(); if(/life ?time|forever|permanent/.test(x)) return null; var m=x.match(/(\\d+)\\s*(day|week|month|year)/); if(m){ var n=parseInt(m[1],10)||1,u=m[2]; return u==='day'?n:(u==='week'?n*7:(u==='month'?n*30:n*365)); } if(/year|annual/.test(x)) return 365; if(/month/.test(x)) return 30; if(/week/.test(x)) return 7; return null; }\n" +
  "  function _clDig(v){ var m=String(v==null?'':v).match(/\\d+/); return m?parseInt(m[0],10):0; }\n" +
  "  router.post('/account/tools/claim', requireLogin, function(req, res){ _clMul.single('shot')(req, res, function(){ _clSubmit(req, res); }); });\n" +
  "  async function _clSubmit(req, res){\n" +
  "    const c = req.session.customer; const b = req.body||{};\n" +
  "    const orderNo=String(b.order_no||'').trim(); const message=String(b.message||'').trim().slice(0,1200);\n" +
  "    const shot=(req.file && req.file.filename)?req.file.filename:null;\n" +
  "    if(!orderNo || !message) return res.json({ ok:false, error:'Please choose an order and describe the issue.' });\n" +
  "    try{\n" +
  "      const o=(await pool.query(\"SELECT o.id, o.order_no, o.status, o.plan_label, o.created_at, COALESCE(pp.warranty,p.warranty) AS warranty, bp.warranty_days AS bot_warranty_days FROM orders o LEFT JOIN products p ON p.id=o.product_id LEFT JOIN product_plans pp ON pp.product_id=o.product_id AND pp.label=o.plan_label LEFT JOIN bot_products bp ON bp.sku=o.bot_sku WHERE o.order_no=$1 AND (o.customer_id=$2 OR (o.customer_id IS NULL AND o.email IS NOT NULL AND lower(o.email)=lower($3))) LIMIT 1\",[orderNo,c.id,c.email])).rows[0];\n" +
  "      if(!o) return res.json({ ok:false, error:'We could not match that order to your account.' });\n" +
  "      const done=['delivered','completed','done'].indexOf(String(o.status||'').toLowerCase())>=0;\n" +
  "      if(!done) return res.json({ ok:false, error:'This order isn’t delivered yet, so there’s nothing to replace.' });\n" +
  "      var pur=o.created_at?new Date(o.created_at).getTime():null;\n" +
  "      var warrD=_clDig(o.warranty)||(o.bot_warranty_days||0);\n" +
  "      var wExp=(pur&&warrD)?(pur+warrD*86400000):null;\n" +
  "      if(warrD && !(wExp && wExp>Date.now())) return res.json({ ok:false, error:'This order’s warranty period has ended — please contact support on WhatsApp.' });\n" +
  "      const dup=(await pool.query(\"SELECT id FROM order_issues WHERE order_id=$1 AND status='open' LIMIT 1\",[o.id])).rows[0];\n" +
  "      if(dup) return res.json({ ok:false, error:'You already have a replacement request pending for this order.' });\n" +
  "      const ins=await pool.query(\"INSERT INTO order_issues(order_id, customer_id, kind, message, order_no, status, customer_email, screenshot) VALUES($1,$2,'replacement',$3,$4,'open',$5,$6) RETURNING id\",[o.id, c.id, message, o.order_no, c.email||null, shot]);\n" +
  "      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'issue', type:'issue', order_no:o.order_no, issue_id:ins.rows[0].id, message:('[Replacement] '+message).slice(0,500) }); } }catch(e){}\n" +
  "      res.json({ ok:true });\n" +
  "    }catch(e){ res.json({ ok:false, error:'Could not submit. Please try again.' }); }\n" +
  "  }\n" +
  "  router.get('/account/tools/claims', requireLogin, async (req, res) => {\n" +
  "    const c = req.session.customer; let rows=[];\n" +
  "    try{ rows=(await pool.query(\"SELECT i.id, i.order_no, i.message, i.status, i.decision, i.admin_response, i.admin_screenshot, i.replacement_credentials, i.created_at, i.resolved_at, o.product_name FROM order_issues i LEFT JOIN orders o ON o.id=i.order_id WHERE i.customer_id=$1 ORDER BY i.id DESC LIMIT 30\",[c.id])).rows; }catch(e){}\n" +
  "    res.json({ ok:true, claims: rows.map(function(i){ var closed=['replaced','resolved'].indexOf(String(i.status||'').toLowerCase())>=0; return { id:i.id, order_no:i.order_no, product_name:i.product_name||'', message:i.message, status:i.status, decision:i.decision||'', admin_response:i.admin_response||'', has_shot:!!i.admin_screenshot, credentials: closed?(i.replacement_credentials||''):'', created_at:i.created_at, resolved_at:i.resolved_at }; }) });\n" +
  "  });\n" +
  "  router.get('/account/tools/issue-file/:id', requireLogin, async (req, res) => {\n" +
  "    const c=req.session.customer; const id=parseInt(req.params.id,10)||0;\n" +
  "    try{ const i=(await pool.query(\"SELECT admin_screenshot FROM order_issues WHERE id=$1 AND customer_id=$2 LIMIT 1\",[id,c.id])).rows[0]; if(!i||!i.admin_screenshot) return res.status(404).end(); return res.sendFile(_clP.join(_clDir, _clP.basename(i.admin_screenshot))); }catch(e){ res.status(404).end(); }\n" +
  "  });\n";

if (s.indexOf('/account/tools/claims') >= 0) {
  console.log('skip (already): claim/replace endpoints present');
} else {
  const i = s.indexOf(OLD);
  if (i < 0) throw new Error('ANCHOR MISS: original /account/tools/claim route not found (run after patch_cttools)');
  if (s.indexOf(OLD, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: /account/tools/claim');
  s = s.slice(0, i) + NEW + s.slice(i + OLD.length);
  fs.writeFileSync(file, s);
  console.log('patched: claim upload + eligibility + /claims feed + /issue-file');
}
console.log('CLAIM PATCH OK');
