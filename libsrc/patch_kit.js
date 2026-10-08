'use strict';
/* Promote the premium component kit (stat cards, quick-actions, list panels,
   status pills, filter chips, search) into the admin shell so every section
   shares ONE definition. Inserted once before </style> in _shell_top.ejs. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_kit.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const first = s.indexOf(e.find);
    if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

const KIT = "\n/*premium-kit*/\n" +
".dcards{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:20px}\n" +
"@media(max-width:1100px){.dcards{grid-template-columns:repeat(2,1fr)}}\n" +
"@media(max-width:470px){.dcards{grid-template-columns:1fr}}\n" +
".dcards.c4{grid-template-columns:repeat(4,1fr)}\n" +
"@media(max-width:1100px){.dcards.c4{grid-template-columns:repeat(2,1fr)}}\n" +
"@media(max-width:470px){.dcards.c4{grid-template-columns:1fr}}\n" +
".dcard{display:flex;gap:14px;align-items:center;background:#fff;border-radius:16px;padding:17px 18px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);position:relative;overflow:hidden}\n" +
".dcard:before{content:\"\";position:absolute;top:0;left:0;right:0;height:3px;background:var(--t,var(--grad))}\n" +
".dic{width:48px;height:48px;border-radius:13px;flex:none;display:grid;place-items:center;background:color-mix(in srgb,var(--t,#2a7bff) 14%,#fff);color:var(--t,#2a7bff)}\n" +
".dic svg{width:24px;height:24px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}\n" +
".dmeta{display:flex;flex-direction:column;min-width:0}\n" +
".dlbl{font-size:11.5px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted);font-weight:700}\n" +
".dval{font-family:'Schibsted Grotesk',sans-serif;font-size:25px;font-weight:800;letter-spacing:-.02em;line-height:1.18;margin:2px 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}\n" +
".ssub,.dsub{font-size:12.5px;color:var(--muted);font-weight:600}\n" +
".dsub.alert{color:#b26a00}\n" +
".dacts{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:22px}\n" +
"@media(max-width:820px){.dacts{grid-template-columns:repeat(2,1fr)}}\n" +
".dact{display:flex;align-items:center;gap:11px;background:#fff;border-radius:13px;padding:14px 16px;font-weight:700;font-size:14px;box-shadow:inset 0 0 0 1px var(--hair);transition:.16s}\n" +
".dact:hover{box-shadow:inset 0 0 0 1.5px var(--brand);color:var(--brand);transform:translateY(-1px)}\n" +
".dact svg{width:19px;height:19px;flex:none;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}\n" +
".dpanels{display:grid;grid-template-columns:1.25fr 1fr;gap:18px}\n" +
"@media(max-width:860px){.dpanels{grid-template-columns:1fr}}\n" +
".dpanel{background:#fff;border-radius:16px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);overflow:hidden}\n" +
".dph{display:flex;align-items:center;gap:9px;padding:15px 18px;border-bottom:1px solid var(--hair)}\n" +
".dph b{font-size:15px}\n.dph .sp{flex:1}\n.dph a{font-size:13px;color:var(--brand);font-weight:700}\n" +
".dph svg{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}\n" +
".drow{display:flex;align-items:center;gap:12px;padding:12px 18px;border-top:1px solid var(--hair)}\n" +
".drow:first-of-type{border-top:0}\n.drow .main{flex:1;min-width:0}\n" +
".drow .t{font-weight:700;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}\n" +
".drow .s{font-size:12.5px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}\n" +
".dbadge{font-size:11.5px;font-weight:700;padding:3px 9px;border-radius:20px;white-space:nowrap}\n" +
".damt{font-weight:800;font-size:14px;white-space:nowrap}\n" +
".dempty{padding:22px 18px;color:var(--muted);font-size:14px}\n" +
".pill{font-size:11.5px;font-weight:800;padding:3px 10px;border-radius:20px;white-space:nowrap}\n" +
".chips{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px}\n" +
".chip{display:inline-flex;align-items:center;gap:6px;padding:8px 13px;border-radius:999px;font-weight:700;font-size:13px;background:#fff;color:#44506e;box-shadow:inset 0 0 0 1px var(--hair);transition:.15s}\n" +
".chip:hover{color:var(--brand);box-shadow:inset 0 0 0 1.4px var(--brand)}\n" +
".chip.on{background:var(--grad);color:#fff;box-shadow:none}\n" +
".chip .n{opacity:.75;font-size:11.5px}\n" +
".spill{display:inline-block;font-size:11.5px;font-weight:700;padding:3px 10px;border-radius:999px;text-transform:capitalize;white-space:nowrap}\n" +
".srch{display:flex;gap:10px;align-items:center;margin-bottom:16px;flex-wrap:wrap}\n" +
".srch input{flex:1;min-width:200px;margin:0}\n";

patch('views/admin/_shell_top.ejs', [{
  name: 'premium-kit', guard: '/*premium-kit*/',
  find: '</style>', replace: KIT + '</style>'
}]);
console.log('KIT PATCH OK');
