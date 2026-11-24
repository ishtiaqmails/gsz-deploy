#!/usr/bin/env bash
# stepZayronRemoveEditCounts — remove the manual Live/Movies/Series inputs from the server editor
# (counts now auto-sync from galaxyzayron). Keep them as hidden inputs so a save never wipes the fallback.
set -e
Z=/opt/zayron; cd "$Z"
TS=$(date +%s); B="$Z/.retired/$TS"; mkdir -p "$B"; cp routes/admin.js "$B/admin.js.bak"
revert(){ cp "$B/admin.js.bak" routes/admin.js; pm2 restart zayron >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
      <div class="row">
        <div><label>Live TV channels</label><input name="channels" value="${esc(s.channels)}" placeholder="18,400"></div>
        <div><label>Movies / VOD</label><input name="movies" value="${esc(s.movies)}" placeholder="62k"></div>
        <div><label>Series</label><input name="series" value="${esc(s.series)}" placeholder="9,200"></div>
      </div>
O
cat > "$T/n" <<'O'
      <div class="row"><div style="grid-column:1/-1"><label>Library counts</label><div class="hint">Live channels, movies &amp; series now sync automatically from galaxyzayron &mdash; no need to set them here.</div></div></div>
      <input type="hidden" name="channels" value="${esc(s.channels)}"><input type="hidden" name="movies" value="${esc(s.movies)}"><input type="hidden" name="series" value="${esc(s.series)}">
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2]; const F='routes/admin.js';
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync(F,'utf8'); const O=rd('o'), N=rd('n'); const c=s.split(O).length-1;
if(c!==1){ console.error('ANCHOR x'+c); process.exit(5); }
fs.writeFileSync(F, s.split(O).join(N)); console.log('admin.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
HC=000
for i in $(seq 1 12); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:3500/healthz 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
[ "$HC" = "200" ] || { echo "healthz=$HC after 12s - reverting"; revert; exit 1; }
echo "DONE: manual card-count fields removed from the server editor. healthz=200"
