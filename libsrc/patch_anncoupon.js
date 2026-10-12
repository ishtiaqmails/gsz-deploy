'use strict';
/* Enrich /api/announcements so each item carries the coupon's REAL discount from the
   admin dashboard (coupons.kind + coupons.value), as a ready label: "10% OFF" / "Rs 200 OFF".
   Only ACTIVE, non-expired coupons contribute a label (respect the admin dashboard).
   Modifies the already-product-aware feed route in routes/account.js.
   Idempotent; hard-fails if an anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_anncoupon.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*annCoupon*/') >= 0) { console.log('skip (already): announcements coupon label'); process.exit(0); }
if (s.indexOf('/*annFeedPA*/') < 0) throw new Error('ANCHOR MISS: product-aware feed not present (run patch_annfeed first)');

const JOIN = " LEFT JOIN coupons cp ON lower(cp.code)=lower(a.coupon_code) AND cp.active=true AND (cp.expires_at IS NULL OR cp.expires_at>now())";

/* 1) logged-in query: add coupon columns + join */
const IN_FIND = "SELECT a.id, a.title, a.body, a.kind, a.coupon_code, a.created_at, p.name AS product_name FROM announcements a LEFT JOIN products p ON p.id=a.target_product_id WHERE";
const IN_REPL = "SELECT a.id, a.title, a.body, a.kind, a.coupon_code, a.created_at, p.name AS product_name, cp.kind AS coupon_kind, cp.value AS coupon_value FROM announcements a LEFT JOIN products p ON p.id=a.target_product_id" + JOIN + " WHERE";
if (s.indexOf(IN_FIND) < 0) throw new Error('ANCHOR MISS: logged-in query');
s = s.replace(IN_FIND, IN_REPL);

/* 2) logged-out query: alias announcements as a, qualify cols, add join */
const OUT_FIND = "SELECT id, title, body, kind, coupon_code, created_at, NULL AS product_name FROM announcements WHERE target_product_id IS NULL ORDER BY id DESC LIMIT 8";
const OUT_REPL = "SELECT a.id, a.title, a.body, a.kind, a.coupon_code, a.created_at, NULL AS product_name, cp.kind AS coupon_kind, cp.value AS coupon_value FROM announcements a" + JOIN + " WHERE a.target_product_id IS NULL ORDER BY a.id DESC LIMIT 8";
if (s.indexOf(OUT_FIND) < 0) throw new Error('ANCHOR MISS: logged-out query');
s = s.replace(OUT_FIND, OUT_REPL);

/* 3) mapping: add coupon_label computed from kind+value */
const MAP_FIND = "res.json({ ok:true, items: rows.map(function(a){ return { id:a.id, title:a.title, body:a.body, kind:a.kind||'', coupon:a.coupon_code||'', created_at:a.created_at||null, product:a.product_name||'' }; }) });";
const MAP_REPL = "res.json({ ok:true, items: rows.map(function(a){ /*annCoupon*/ var _cl=''; if(a.coupon_code && a.coupon_kind){ var _v=Number(a.coupon_value)||0; _cl = (a.coupon_kind==='percent') ? (_v+'% OFF') : ('Rs '+Math.round(_v).toLocaleString('en-US')+' OFF'); } return { id:a.id, title:a.title, body:a.body, kind:a.kind||'', coupon:a.coupon_code||'', coupon_label:_cl, created_at:a.created_at||null, product:a.product_name||'' }; }) });";
if (s.indexOf(MAP_FIND) < 0) throw new Error('ANCHOR MISS: feed mapping');
s = s.replace(MAP_FIND, MAP_REPL);

fs.writeFileSync(file, s);
console.log('ANNOUNCEMENTS COUPON-LABEL PATCH OK');
