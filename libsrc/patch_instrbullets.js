'use strict';
/* Auto-bullet Delivery instructions.
   ADMIN (views/admin/product_model.ejs): the .p_dinstr field starts with a bullet, Enter adds the
   next bullet, value is normalised on blur, LOADS bulletised and SAVES as clean plain lines
   (no bullet char) so every delivery channel adds its own suitable bullet (no doubles).
   HUB (views/partials/hub_model.ejs): render order delivery_instructions as a bulleted list too.
   Single-line anchors, CRLF-safe, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_instrbullets.js <ROOT>'); process.exit(1); }
const PM = path.join(ROOT, 'views/admin/product_model.ejs');
const HB = path.join(ROOT, 'views/partials/hub_model.ejs');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}

// A) placeholder hint
once(PM, 'pm:placeholder', 'a bullet is added automatically',
  "<textarea class=\"p_dinstr\" placeholder=\"Sent to the customer after delivery\"></textarea>",
  "<textarea class=\"p_dinstr\" placeholder=\"Type one instruction per line — a bullet is added automatically\"></textarea>");

// B) load -> bulletize + wire
once(PM, 'pm:load', "pmBulletize(d.delivery_instructions",
  "el.querySelector('.p_dinstr').value=d.delivery_instructions||'';",
  "el.querySelector('.p_dinstr').value=pmBulletize(d.delivery_instructions||''); pmWireBullets(el.querySelector('.p_dinstr'));");

// C) save -> debullet (store clean plain lines)
once(PM, 'pm:save', "pmDebullet(p.querySelector('.p_dinstr')",
  "delivery_instructions:p.querySelector('.p_dinstr').value,",
  "delivery_instructions:pmDebullet(p.querySelector('.p_dinstr').value),");

// D) helpers before pmAddPlan
const HELP =
  "function pmBulletize(t){ return String(t||'').split(/\\r?\\n/).map(function(l){ var x=l.replace(/^\\s*(?:[\\u2022\\u2013\\u2014*-]|\\d+[.)])\\s*/,'').trim(); return x?('\\u2022 '+x):''; }).filter(Boolean).join('\\n'); }\n" +
  "  function pmDebullet(t){ return String(t||'').split(/\\r?\\n/).map(function(l){ return l.replace(/^\\s*(?:[\\u2022\\u2013\\u2014*-]|\\d+[.)])\\s*/,'').trim(); }).filter(Boolean).join('\\n'); }\n" +
  "  function pmWireBullets(ta){ if(!ta||ta._bw) return; ta._bw=1;\n" +
  "    ta.addEventListener('focus',function(){ if(!ta.value.trim()) ta.value='\\u2022 '; });\n" +
  "    ta.addEventListener('keydown',function(e){ if(e.key==='Enter'){ e.preventDefault(); var s=ta.selectionStart,en=ta.selectionEnd,v=ta.value; ta.value=v.slice(0,s)+'\\n\\u2022 '+v.slice(en); var p=s+3; ta.selectionStart=ta.selectionEnd=p; } });\n" +
  "    ta.addEventListener('blur',function(){ ta.value=pmBulletize(ta.value); });\n" +
  "  }\n" +
  "  window.pmAddPlan=function(d){";
once(PM, 'pm:helpers', 'function pmWireBullets(', 'window.pmAddPlan=function(d){', HELP);

// E) hub order-detail delivery_instructions -> bulleted list
once(HB, 'hub:instr-bullets', "o.delivery_instructions).split('\\n')",
  "<pre style=\"margin:0;white-space:pre-wrap;word-break:break-word;background:#0e1627;border:1px solid rgba(41,211,255,.28);border-radius:10px;padding:10px;font-size:13px\">'+esc(o.delivery_instructions)+'</pre>",
  "<div style=\"background:#0e1627;border:1px solid rgba(41,211,255,.28);border-radius:10px;padding:10px 12px;font-size:13px;line-height:1.75;color:#eef1ff\">'+esc(o.delivery_instructions).split('\\n').map(function(x){return x.trim();}).filter(Boolean).map(function(x){return '\\u2022 '+x;}).join('<br>')+'</div>");

console.log('INSTRBULLETS PATCH OK');
