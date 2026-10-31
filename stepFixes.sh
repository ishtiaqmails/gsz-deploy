#!/usr/bin/env bash
# stepFixes.sh — three fixes in one:
#  1) Geo admin page rebuilt in the LIGHT admin shell (_shell_top/_shell_bottom).
#  2) Admin sidebar: add the 6 hidden pages (Geo SEO, Waitlist, Mapping, Labels,
#     Bot Status, WhatsApp Bot) so nothing is buried.
#  3) Reseller panel prices made currency-aware (use the site's paintPrices engine
#     instead of hardcoded "PKR").
# All view-layer, anchor-checked (split/join), ejs-compiled, backed up + rolled back.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3600}
TS=$(date +%s); BAKDIR="$GSZ/.fixbak.$TS"; mkdir -p "$BAKDIR"

ST="$GSZ/views/admin/_shell_top.ejs"
RS="$GSZ/views/resellers.ejs"
GE="$GSZ/views/admin/geo.ejs"
export ST RS GE

restore(){
  echo "!! failed — rolling back"
  [ -f "$BAKDIR/_shell_top.ejs" ] && cp -f "$BAKDIR/_shell_top.ejs" "$ST"
  [ -f "$BAKDIR/resellers.ejs" ] && cp -f "$BAKDIR/resellers.ejs" "$RS"
  [ -f "$BAKDIR/geo.ejs" ] && cp -f "$BAKDIR/geo.ejs" "$GE"
  pm2 restart "$APP" >/dev/null 2>&1
  exit 1
}
trap restore ERR

echo "==> backup"
cp -f "$ST" "$BAKDIR/_shell_top.ejs"; cp -f "$RS" "$BAKDIR/resellers.ejs"; cp -f "$GE" "$BAKDIR/geo.ejs" 2>/dev/null || true

echo "==> 1) geo admin -> light shell"
cp -f "$DEPLOY/views/admin/geo.ejs" "$GE"

echo "==> 2) admin sidebar: add 6 hidden pages"
node <<'NODE'
const fs=require('fs'); const F=process.env.ST || '/opt/gsz/views/admin/_shell_top.ejs';
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('ADMIN_NAV_FULL')>=0){ console.log('   nav already patched'); process.exit(0); }
function ins(anchor, add){ const n=s.split(anchor).length-1; if(n!==1) throw new Error('nav anchor not unique/found ('+n+'): '+anchor.slice(0,40)); s=s.split(anchor).join(anchor+add); } // append AFTER
function pre(anchor, add){ const n=s.split(anchor).length-1; if(n!==1) throw new Error('nav anchor not unique/found ('+n+'): '+anchor.slice(0,40)); s=s.split(anchor).join(add+anchor); } // insert BEFORE
// Waitlist after Issues (Sales)
ins('</svg>Issues</a>', '\n    <a href="/admin/waitlist" class="<%= on(\'waitlist\') %>"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>Restock Waitlist</a>');
// Mapping + Labels after Categories (Catalog)
ins('</svg>Categories</a>', '\n    <a href="/admin/mapping" class="<%= on(\'mapping\') %>"><svg viewBox="0 0 24 24"><path d="M4 7h16M4 12h16M4 17h10"/><circle cx="19" cy="17" r="2"/></svg>Product Mapping</a>\n    <a href="/admin/labels" class="<%= on(\'labels\') %>"><svg viewBox="0 0 24 24"><path d="M20.6 11.4 12 20l-8-8V4h8z"/><circle cx="8" cy="8" r="1.4"/></svg>Type Labels</a>');
// SEO group + Geo BEFORE Storefront group
pre('<div class="grp">Storefront</div>', '<div class="grp">SEO</div>\n    <a href="/admin/geo" class="<%= on(\'geo\') %>"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3a15 15 0 0 1 0 18M12 3a15 15 0 0 0 0 18"/></svg>Geo SEO Pages</a>\n    ');
// Bots group BEFORE </nav>  /*ADMIN_NAV_FULL*/
pre('  </nav>', '  <div class="grp">Bots &amp; System</div>\n    <a href="/admin/bot/status" class="<%= on(\'bot\') %>"><svg viewBox="0 0 24 24"><rect x="4" y="8" width="16" height="12" rx="2"/><path d="M12 8V5M9 14h.01M15 14h.01"/></svg>Bot Status</a>\n    <a href="/admin/wabot" class="<%= on(\'wabot\') %>"><svg viewBox="0 0 24 24"><path d="M21 11.5a8.4 8.4 0 0 1-12.4 7.4L3 21l2.2-5.4A8.5 8.5 0 1 1 21 11.5Z"/></svg>WhatsApp Bot</a>\n  <!--ADMIN_NAV_FULL-->\n');
fs.writeFileSync(F,s); console.log('   added 6 nav links');
NODE

echo "==> 3) reseller prices -> currency-aware"
node <<'NODE'
const fs=require('fs'); const F=process.env.RS || '/opt/gsz/views/resellers.ejs';
let s=fs.readFileSync(F,'utf8');
if(s.indexOf('RESELLER_CUR_FIX')>=0){ console.log('   reseller already patched'); process.exit(0); }
function rep(oldS, newS){ const n=s.split(oldS).length-1; if(n!==1) throw new Error('reseller anchor not unique/found ('+n+'): '+oldS.slice(0,40)); s=s.split(oldS).join(newS); }
// markup: total + per become .pprice spans
rep('<div class="v js-total"></div>', '<div class="v"><span class="pprice js-total" data-pkr="0" data-usd=""></span></div>');
rep('<span class="rp-per js-per"></span>', '<span class="rp-per"><span class="pprice js-per" data-pkr="0" data-usd=""></span> / credit</span>');
// JS: feed data attrs + paint via site engine  /*RESELLER_CUR_FIX*/
rep("if(tEl) tEl.textContent = cur + ' ' + fmt(total);",
    "var _ba=(cur==='USD')?'data-usd':'data-pkr',_oa=(cur==='USD')?'data-pkr':'data-usd'; /*RESELLER_CUR_FIX*/\n      if(tEl){ tEl.setAttribute(_ba,total); tEl.setAttribute(_oa,''); }");
rep("if(pEl) pEl.textContent = cur + ' ' + fmt(t.price) + ' / credit';",
    "if(pEl){ pEl.setAttribute(_ba,t.price); pEl.setAttribute(_oa,''); }\n      if(window.GSZ&&typeof window.GSZ.paintPrices==='function'){ try{ window.GSZ.paintPrices(card); }catch(e){} }\n      else { if(tEl) tEl.textContent=cur+' '+fmt(total); if(pEl) pEl.textContent=cur+' '+fmt(t.price); }");
fs.writeFileSync(F,s); console.log('   reseller calculator now currency-aware');
NODE

echo "==> ejs compile all three"
node -e 'const ejs=require("'"$GSZ"'/node_modules/ejs"),fs=require("fs");["views/admin/geo.ejs","views/admin/_shell_top.ejs","views/resellers.ejs"].forEach(function(p){ejs.compile(fs.readFileSync("'"$GSZ"'/"+p,"utf8"),{filename:"'"$GSZ"'/"+p});});console.log("   all compile OK")'

echo "==> restart"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "   health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo
echo "DONE. Check:"
echo "  • /admin  — sidebar now has Geo SEO, Restock Waitlist, Product Mapping, Type Labels, Bot Status, WhatsApp Bot"
echo "  • /admin/geo — now matches your light admin theme + full sidebar"
echo "  • /resellers — change currency; prices now follow it (no more fixed PKR)"
echo "Backups: $BAKDIR"
