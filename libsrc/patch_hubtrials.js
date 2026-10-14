'use strict';
/* Premium per-type trial detail inside the Galaxy Hub modal (phone + desktop).
   1) routes/account.js  /account/tools/trials : expose `fields` (from metadata) in the JSON.
   2) views/partials/hub_model.ejs :
      a) add .th* styles (responsive) into the hub <style>,
      b) add renderTrialCred(t) helper before trialDetail(),
      c) swap the raw <pre> cred builder for renderTrialCred(t).
   Single-line / span anchors, CRLF-safe, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_hubtrials.js <ROOT>'); process.exit(1); }
const AC = path.join(ROOT, 'routes/account.js');
const HB = path.join(ROOT, 'views/partials/hub_model.ejs');

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + find.length) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}
function span(file, name, guard, startStr, endStr, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(j + endStr.length));
  console.log('patched: ' + name);
}

// 1) expose fields in the tools/trials JSON
once(AC, 'account:trials-fields', 'fields:(md.fields&&md.fields.delivery_type',
  'convertable: windowOpen };',
  'convertable: windowOpen, fields:(md.fields&&md.fields.delivery_type&&done)?md.fields:null };');

// 2a) responsive styles for the per-type trial block
const CSS =
  ".thsec{font-size:11px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:14px 0 8px}\n" +
  "  .thtbl{width:100%;border-collapse:collapse}\n" +
  "  .thtbl td{padding:8px 0;border-top:1px solid rgba(255,255,255,.08);font-size:13.5px;vertical-align:top}\n" +
  "  .thtbl td.thk{color:#8b93bb;white-space:nowrap;padding-right:12px;width:1%}\n" +
  "  .thtbl td.thv{color:#eef1ff;font-family:Consolas,Menlo,monospace;word-break:break-all;-webkit-user-select:all;user-select:all}\n" +
  "  .thpl{display:flex;flex-wrap:wrap;gap:8px}\n" +
  "  .thpl a{display:inline-flex;align-items:center;gap:6px;background:rgba(59,130,255,.14);border:1px solid rgba(59,130,255,.3);color:#9cc2ff;text-decoration:none;font-weight:700;font-size:12.5px;padding:7px 12px;border-radius:9px}\n" +
  "  .thpl a:hover{background:rgba(59,130,255,.22)}\n" +
  "  .thexp{margin-top:10px;font-size:12px;color:#8b93bb}\n" +
  "  @media(max-width:560px){.thpl a{flex:1;justify-content:center}}\n" +
  "  .sb-act a,.sb-act button{text-decoration:none}";
once(HB, 'hub:th-styles', '.thtbl{width:100%',
  '.sb-act a,.sb-act button{text-decoration:none}', CSS);

// 2b) renderTrialCred helper before trialDetail()
const RTC =
  "function renderTrialCred(t){\n" +
  "    var f = (t.fields && t.fields.delivery_type) ? t.fields : null;\n" +
  "    if(!t.credentials && !f){ return '<div class=\"cthm-note\">'+(t.pending?'Your trial is being set up — check back in a moment.':'No login available for this trial.')+'</div>'; }\n" +
  "    if(f){\n" +
  "      var dt=f.delivery_type;\n" +
  "      var title = dt==='iptv'?'Your line':'Your login';\n" +
  "      var dd=(f.details||[]).filter(function(d){return d&&d.value&&String(d.label||'').toLowerCase()!=='support';});\n" +
  "      var rows=dd.map(function(d){return '<tr><td class=\"thk\">'+esc(d.label)+'</td><td class=\"thv\">'+esc(d.value)+'</td></tr>';}).join('');\n" +
  "      var pl='';\n" +
  "      if(dt==='iptv' && (f.players||[]).length){ pl='<div class=\"thsec\">Watch on</div><div class=\"thpl\">'+(f.players||[]).map(function(p){return '<a href=\"'+esc(p.url||'#')+'\" target=\"_blank\" rel=\"noopener\">'+esc(p.platform||'App')+'</a>';}).join('')+'</div>'; }\n" +
  "      var exp=f.expiry?('<div class=\"thexp\">Expires: '+esc(f.expiry)+'</div>'):'';\n" +
  "      return '<div class=\"cthm-cred\"><div style=\"display:flex;justify-content:space-between;align-items:center;margin-bottom:8px\"><span class=\"thsec\" style=\"margin:0\">'+esc(title)+'</span><button class=\"cbtn cbtn-g\" style=\"padding:5px 12px;font-size:12px\" id=\"tCpy\">Copy</button></div><table class=\"thtbl\">'+rows+'</table>'+pl+exp+'</div>';\n" +
  "    }\n" +
  "    return '<div class=\"cthm-cred\"><div style=\"display:flex;justify-content:space-between;align-items:center;margin-bottom:6px\"><span class=\"muted\">Trial login</span><button class=\"cbtn cbtn-g\" style=\"padding:5px 12px;font-size:12px\" id=\"tCpy\">Copy</button></div><pre style=\"margin:0;white-space:pre-wrap;word-break:break-word;background:#0e1627;border:1px solid rgba(255,255,255,.08);border-radius:10px;padding:10px;font-size:13px\">'+esc(t.credentials)+'</pre></div>';\n" +
  "  }\n" +
  "  function trialDetail(t){";
once(HB, 'hub:rtc-helper', 'function renderTrialCred(t){',
  'function trialDetail(t){', RTC);

// 2c) use the helper in trialDetail
span(HB, 'hub:use-rtc', 'var cred = renderTrialCred(t);',
  'var cred = t.credentials?(',
  "No login available for this trial.')+'</div>');",
  'var cred = renderTrialCred(t);');

console.log('HUBTRIALS PATCH OK');
