#!/usr/bin/env bash
# gsz-sweep28 : tag IPTV suggestion cards on the product page with is-iptv, so the
# existing counts engine paints Live/Movies/Series on them (same as the homepage).
# One-line template change. Safe: backup, 1-match guard, EJS validate, auto-revert.
set -e
cd /opt/gsz
F=views/product.ejs
cp "$F" /opt/gsz/.gsz-s28-prod.bak

cat > /tmp/gsz_prod_patch.js <<'PATCH'
const fs=require('fs');
const f='/opt/gsz/views/product.ejs';
let s=fs.readFileSync(f,'utf8');
if(s.indexOf("s.cat===")!==-1){ console.error('ALREADY PATCHED'); process.exit(3); }
const a='<a class="pcard" href="/product/<%= s.slug %>">';
if(s.split(a).length-1 !== 1){ console.error('anchor count != 1'); process.exit(4); }
const b='<a class="pcard<%= s.cat===\'iptv\' ? \' is-iptv\' : \'\' %>" href="/product/<%= s.slug %>">';
s=s.replace(a,b);
fs.writeFileSync(f,s);
console.log('PATCHED OK');
PATCH

node /tmp/gsz_prod_patch.js || { echo "patch failed - reverting"; cp /opt/gsz/.gsz-s28-prod.bak "$F"; exit 1; }
node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" || { echo "EJS error - reverting"; cp /opt/gsz/.gsz-s28-prod.bak "$F"; exit 1; }

pm2 restart gsz
echo "DONE: IPTV suggestion cards now carry is-iptv (counts will show)."
