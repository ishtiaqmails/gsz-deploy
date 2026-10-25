#!/usr/bin/env bash
# stepGstoreMigrate.sh — migrate galaxytools.net (/opt/galaxystore) Netflix code reader to the NEW
#   gzportal API (codes-only). Deploys lib/nfMail.js + lib/netflixGate.js, repoints to Bearer auth.
#   First run: pass the key ->  NF_KEY='gzp_...' bash stepGstoreMigrate.sh
#   Idempotent; restores on failure. Read-only self-test at the end.
set -euo pipefail
GS=/opt/galaxystore; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
[ -d "$GS/lib" ] || { echo "ABORT: $GS not found"; exit 1; }
BK="$GS/.bak-nfmig-$TS"; cd "$GS"
FILES="lib/nfMail.js lib/netflixGate.js .env"
mkdir -p "$BK/lib"
for f in $FILES; do [ -f "$GS/$f" ] && cp "$GS/$f" "$BK/$f" || true; done
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; for f in $FILES; do [ -f "$BK/$f" ] && cp "$BK/$f" "$GS/$f" || true; done; }
trap restore ERR

set_env(){ local k="$1" v="$2"; if grep -q "^$k=" "$GS/.env" 2>/dev/null; then sed -i "s|^$k=.*|$k=$v|" "$GS/.env"; else printf '%s=%s\n' "$k" "$v" >> "$GS/.env"; fi; }
if [ -n "${NF_KEY:-}" ]; then
  set_env NF_PORTAL_URL "https://app.galaxyzayron.store/api/v1"
  set_env NF_READ_KEY "$NF_KEY"
  echo "   .env updated: NF_PORTAL_URL + NF_READ_KEY (Bearer)"
else
  echo "   NF_KEY not passed — using existing .env"
fi

echo "==> deploy nfMail + netflixGate"
cp -f "$SRC/gstore_nfMail.js"      "$GS/lib/nfMail.js"
cp -f "$SRC/gstore_netflixGate.js" "$GS/lib/netflixGate.js"
node --check "$GS/lib/nfMail.js" && echo "   nfMail.js ok"
node --check "$GS/lib/netflixGate.js" && echo "   netflixGate.js ok"

echo "==> restart galaxytools.net (auto-detect PM2 app by cwd)"
APP=$(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const a=JSON.parse(d);const m=a.find(x=>x.pm2_env&&x.pm2_env.pm_cwd&&String(x.pm2_env.pm_cwd).indexOf("/opt/galaxystore")===0);process.stdout.write(m?m.name:"");}catch(e){}})' 2>/dev/null || true)
trap - ERR
if [ -n "$APP" ]; then pm2 restart "$APP" --update-env >/dev/null && echo "   restarted PM2 app: $APP"; else echo "   WARN: could not auto-detect the galaxystore PM2 app — restart it manually (pm2 restart <name>)"; fi

echo "==> read-only self-test (new API via deployed libs)"
node - "$GS" <<'NODE' || echo "   (self-test error — non-fatal; check .env key)"
const R=process.argv[2];
require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const nfMail=require(R+'/lib/nfMail'), gate=require(R+'/lib/netflixGate');
function rtypes(em,lab){ const g={}; gate.filterEmails(em, gate.allowedTypesFor(lab)).forEach(e=>{ if(!g[e.type]) g[e.type]=1; }); return Object.keys(g); }
(async()=>{
  console.log('   configured:', nfMail.configured());
  const m=await nfMail.listForAccount('saphirenn89@outlook.com', true);
  console.log('   real account: ok='+m.ok+' codes='+(m.emails||[]).length);
  const links=(m.emails||[]).map(e=>e.link).filter(Boolean);
  console.log('   links decoded: '+(!links.some(l=>/&amp;|&lt;/.test(l))));
  const d=await nfMail.listForAccount('testnetflix@galaxy.pk', true);
  console.log('   demo Phone shows:', rtypes(d.emails,'Phone').join(', ')||'(none)');
  console.log('   demo TV    shows:', rtypes(d.emails,'TV plan').join(', ')||'(none)');
  console.log('   demo Full  shows:', rtypes(d.emails,'Full account').join(', ')||'(none)');
})().catch(e=>console.error('   selftest err', e.message));
NODE
echo "DONE — galaxytools.net Netflix codes now read from the new Bearer API. No site depends on the old portal anymore."
