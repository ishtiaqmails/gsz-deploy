'use strict';
/* Product page plan pills:
   (1) "Save X%" chip — for multi-plan products, each longer plan shows how much the customer
       saves per month vs the costliest-per-month plan (the baseline, usually the 1-month plan).
       Pure view maths from the plan label's duration — no DB change.
   (2) "Most Popular" ribbon + glow on any plan flagged pl.popular (the admin flag + persistence
       is wired separately; until it exists this simply never renders — fully safe).
   Idempotent in-place patch of views/product.ejs. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_savepct.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'views/product.ejs');
let s = fs.readFileSync(file, 'utf8');
let changed = false;

/* (A) CSS — add save chip + popular ribbon/glow after the oos rule */
const CSS_ANCHOR = ".ppill.oos{opacity:.6} .ppill.oos .ppill-now{text-decoration:line-through;opacity:.6}";
const CSS_ADD =
  "\n  /* savepct + most-popular */" +
  "\n  .ppill-save{align-self:flex-start;font-size:10.5px;font-weight:800;letter-spacing:.02em;color:#2ad17f;background:rgba(42,209,127,.14);border:1px solid rgba(42,209,127,.32);padding:2px 8px;border-radius:999px;margin-top:1px}" +
  "\n  .ppill.pop{border-color:var(--b2,#29d3ff);box-shadow:0 0 0 2px rgba(41,211,255,.22),0 12px 28px -14px rgba(41,211,255,.55)}" +
  "\n  .ppill-pop{position:absolute;top:-9px;left:-7px;background:linear-gradient(135deg,#9a6cff,#5b8bff);color:#fff;font-size:10px;font-weight:800;letter-spacing:.02em;padding:2px 8px;border-radius:999px;box-shadow:0 5px 14px -5px rgba(91,139,255,.9);white-space:nowrap;display:inline-flex;align-items:center;gap:3px}";
if (s.indexOf(".ppill-save{") < 0 && s.indexOf(CSS_ANCHOR) >= 0) {
  s = s.replace(CSS_ANCHOR, CSS_ANCHOR + CSS_ADD); changed = true; console.log('A: css added');
} else { console.log('A: css present or anchor missing (skip)'); }

/* (B) pre-compute baseline per-month + savePct helper, injected before the plans loop */
const LOOP = "<% plans.forEach(function(pl,i){ var off=(pl.old>pl.price && pl.old>0)?Math.round((1-pl.price/pl.old)*100):0; var oos=(typeof pl.in_stock!=='undefined' && pl.in_stock===false); %>";
const PRE =
  "<% var _mo=function(lab){lab=String(lab||'').toLowerCase();var m;if(/(lifetime|life ?time|perm)/.test(lab))return 0;" +
  "m=lab.match(/(\\d+(?:\\.\\d+)?)\\s*(?:years?|yrs?|y)\\b/);if(m)return parseFloat(m[1])*12;" +
  "m=lab.match(/(\\d+(?:\\.\\d+)?)\\s*(?:months?|mos?|m)\\b/);if(m)return parseFloat(m[1]);" +
  "m=lab.match(/(\\d+(?:\\.\\d+)?)\\s*(?:weeks?|wks?|w)\\b/);if(m)return parseFloat(m[1])/4.345;" +
  "m=lab.match(/(\\d+(?:\\.\\d+)?)\\s*(?:days?|d)\\b/);if(m)return parseFloat(m[1])/30;return 0;};" +
  "var _base=0;plans.forEach(function(pl){var mo=_mo(pl.label);if(mo>0&&pl.price>0){var pm=pl.price/mo;if(pm>_base)_base=pm;}});" +
  "var _savePct=function(pl){var mo=_mo(pl.label);if(!(mo>1)||!(pl.price>0)||!(_base>0))return 0;var s=Math.round((1-(pl.price/mo)/_base)*100);return s>=3?s:0;}; %>\n        ";
if (s.indexOf("var _savePct=") < 0 && s.indexOf(LOOP) >= 0) {
  s = s.replace(LOOP, PRE + LOOP); changed = true; console.log('B: savePct precompute injected');
} else { console.log('B: precompute present or loop anchor missing (skip)'); }

/* (C) add the popular class to the pill button */
const BTN = 'class="ppill<%= i===0?\' sel\':\'\' %><%= oos?\' oos\':\'\' %>" data-label=';
const BTN2 = 'class="ppill<%= i===0?\' sel\':\'\' %><%= oos?\' oos\':\'\' %><%= pl.popular?\' pop\':\'\' %>" data-label=';
if (s.indexOf('pl.popular?\' pop\'') < 0 && s.indexOf(BTN) >= 0) {
  s = s.replace(BTN, BTN2); changed = true; console.log('C: popular class added');
} else { console.log('C: popular class present or anchor missing (skip)'); }

/* (D) popular ribbon after the off badge */
const OFFBADGE = "<% if (off>0) { %><span class=\"ppill-off\">-<%= off %>%</span><% } %>";
const POPRIB = OFFBADGE + "<% if (pl.popular) { %><span class=\"ppill-pop\">★ Most Popular</span><% } %>";
if (s.indexOf('class="ppill-pop"') < 0 && s.indexOf(OFFBADGE) >= 0) {
  s = s.replace(OFFBADGE, POPRIB); changed = true; console.log('D: popular ribbon added');
} else { console.log('D: ribbon present or anchor missing (skip)'); }

/* (E) save chip after the price row */
const PRICEROW = "<span class=\"ppill-price\"><% if (off>0) { %><span class=\"ppill-was\" data-pkr=\"<%= pl.old %>\"></span><% } %><span class=\"ppill-now\" data-pkr=\"<%= pl.price %>\"></span></span>";
const PRICEROW2 = PRICEROW + "<% if (_savePct(pl)>0) { %><span class=\"ppill-save\">Save <%= _savePct(pl) %>%</span><% } %>";
if (s.indexOf('class="ppill-save"') < 0 && s.indexOf(PRICEROW) >= 0) {
  s = s.replace(PRICEROW, PRICEROW2); changed = true; console.log('E: save chip added');
} else { console.log('E: save chip present or anchor missing (skip)'); }

if (changed) fs.writeFileSync(file, s);
console.log('SAVEPCT OK');
