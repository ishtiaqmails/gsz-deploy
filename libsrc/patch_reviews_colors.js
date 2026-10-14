'use strict';
/* Recolor the product-page review UI to the dark store theme (it shipped light). Replaces the
   rv-* <style> block inserted by patch_reviews_r2.js. Single-line anchor, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_reviews_colors.js <ROOT>'); process.exit(1); }
const PV = path.join(ROOT, 'views/product.ejs');
let s = fs.readFileSync(PV, 'utf8');

const LIGHT = "<style>.rv-wrap{margin-top:18px}.rv-item{border-top:1px solid #eef1f8;padding:14px 0}.rv-h{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.rv-auth{font-weight:700;color:#0f1836}.rv-vb{font-size:11.5px;font-weight:700;color:#0b7a42;background:#e7f8ee;border-radius:999px;padding:2px 9px}.rv-st{color:#f5a524;letter-spacing:1px}.rv-t{font-weight:700;margin:6px 0 2px;color:#0f1836}.rv-b{color:#4a5578;font-size:14.5px;line-height:1.6;margin:0}.rv-form{margin-top:18px;background:#f7f9fe;border:1px solid #eaf0ff;border-radius:14px;padding:16px 18px}.rv-form .fld{display:block;font-size:12.5px;font-weight:700;color:#737e9c;margin:10px 0 5px}.rv-form select,.rv-form input,.rv-form textarea{width:100%;box-sizing:border-box;border:1px solid #dfe5f2;border-radius:10px;padding:10px 12px;font:inherit}.rv-ft{font-weight:800;font-size:15px;color:#0f1836;margin:0 0 4px}.rv-ok{color:#0b7a42;font-weight:700;margin:12px 0 0}.rv-note{color:#8b93bb;font-size:12.5px;margin-top:8px}</style>";

const DARK = "<style>.rv-wrap{margin-top:18px}.rv-item{border-top:1px solid var(--line,rgba(255,255,255,.08));padding:14px 0}.rv-h{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.rv-auth{font-weight:700;color:var(--ink,#eef1ff)}.rv-vb{font-size:11.5px;font-weight:700;color:#38d98a;background:rgba(22,183,101,.16);border:1px solid rgba(22,183,101,.3);border-radius:999px;padding:2px 9px}.rv-st{color:#f5a524;letter-spacing:1px}.rv-t{font-weight:700;margin:6px 0 2px;color:var(--ink,#eef1ff)}.rv-b{color:var(--ink-soft,#c4cae8);font-size:14.5px;line-height:1.6;margin:0}.rv-form{margin-top:18px;background:rgba(255,255,255,.03);border:1px solid var(--line-2,rgba(255,255,255,.16));border-radius:14px;padding:16px 18px}.rv-form .fld{display:block;font-size:12.5px;font-weight:700;color:var(--muted,#8b93bb);margin:10px 0 5px}.rv-form select,.rv-form input,.rv-form textarea{width:100%;box-sizing:border-box;border:1px solid var(--line-2,rgba(255,255,255,.16));border-radius:10px;padding:10px 12px;font:inherit;background:#0b1020;color:var(--ink,#eef1ff)}.rv-ft{font-weight:800;font-size:15px;color:var(--ink,#eef1ff);margin:0 0 4px}.rv-ok{color:#38d98a;font-weight:700;margin:12px 0 0}.rv-note{color:var(--muted,#8b93bb);font-size:12.5px;margin-top:8px}</style>";

if (s.indexOf(DARK) >= 0) { console.log('skip (already): rv-dark'); process.exit(0); }
const i = s.indexOf(LIGHT);
if (i < 0) throw new Error('ANCHOR MISS: rv light style');
fs.writeFileSync(PV, s.slice(0, i) + DARK + s.slice(i + LIGHT.length));
console.log('patched: rv-dark (product review styles -> dark theme)');
