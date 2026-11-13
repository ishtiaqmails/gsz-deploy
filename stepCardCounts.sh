#!/usr/bin/env bash
# gsz-stepCardCounts : IPTV product-card counts (Live/Movies/Series) were cached in sessionStorage
# (key gsz_ic) with no TTL or version. Once a card stored a count it was frozen for the whole browser
# session, so after a library grew (B1G 16039 -> 26611) the card kept showing the OLD number; a failed
# or empty fetch was frozen the same way, leaving cards blank. The data path is already correct
# (summary.json returns raw_live for every server). Fix is purely client-side in public/js/app.js:
#   - no sessionStorage persistence (in-memory dedup only, within a single page load)
#   - cache POSITIVE results only, so a stale/failed value never sticks
# Browsers pick up the new app.js because the mtime-based asset version is recomputed on pm2 restart.
# Safe: backup, 1-match anchor guards, node --check, auto-revert on any failure.
set -e
cd /opt/gsz
F=public/js/app.js
cp "$F" /opt/gsz/.gsz-cardcounts.bak

cat > /tmp/gsz_cardcounts_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/public/js/app.js';
let s=fs.readFileSync(f,'utf8');
function rep(o,n){ const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+': '+o.slice(0,52)); process.exit(5);} s=s.replace(o,()=>n); }

// 1) stop loading the persisted cache — in-memory only
rep(
"  var cache={}; try{cache=JSON.parse(sessionStorage.getItem('gsz_ic')||'{}')||{}}catch(e){}",
"  var cache={}; // in-memory only for this page load; summary.json is cheap and counts change daily, so never persist a stale/failed value"
);

// 2) remove the save() helper entirely (no persistence)
rep(
"  function save(){try{sessionStorage.setItem('gsz_ic',JSON.stringify(cache))}catch(e){}}\n",
""
);

// 3) only skip a fetch when we already hold a POSITIVE result (undefined/0 -> fetch fresh)
rep(
"    if(cache[slug]!==undefined){if(cache[slug])paint(card,cache[slug]);return;}",
"    if(cache[slug]){paint(card,cache[slug]);return;}"
);

// 4) cache + paint only real counts; never store 0 / a failed fetch
rep(
"        cache[slug]=v;save();if(v)paint(card,v);",
"        if(v){cache[slug]=v;paint(card,v);}"
);

fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_cardcounts_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-cardcounts.bak "$F"; exit 1; }
node --check "$F" || { echo "syntax error - reverting"; cp /opt/gsz/.gsz-cardcounts.bak "$F"; exit 1; }

pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
echo "DONE: IPTV card counts now always fetch fresh. Asset version bumped on restart — reload /category/iptv and every card shows its real counts."
