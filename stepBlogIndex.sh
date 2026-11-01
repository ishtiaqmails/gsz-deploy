#!/usr/bin/env bash
# stepBlogIndex.sh — instant IndexNow on blog publish/edit/delete. Hooks lib/blog_ping into the
# three publish points in routes/csAdmin.js (save, status-change, delete). Reuses the existing
# IndexNow engine. Fire-and-forget: never blocks or breaks a save. Your blog flow is untouched.
set -uo pipefail
GSZ=/opt/gsz; DEPLOY=/opt/gsz-deploy; APP=${GSZ_APP:-gsz}
PORT=$(grep -E '^PORT=' "$GSZ/.env" 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s); BAKDIR="$GSZ/.blogidxbak.$TS"; mkdir -p "$BAKDIR"
CA="$GSZ/routes/csAdmin.js"; BP="$GSZ/lib/blog_ping.js"
restore(){ echo "!! failed — rolling back"; [ -f "$BAKDIR/csAdmin.js" ] && cp -f "$BAKDIR/csAdmin.js" "$CA"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
trap restore ERR
echo "==> backup"; cp -f "$CA" "$BAKDIR/csAdmin.js"
echo "==> deploy lib/blog_ping.js"; cp -f "$DEPLOY/lib/blog_ping.js" "$BP"; node --check "$BP"

echo "==> patch routes/csAdmin.js (3 publish hooks)"
export CA
node <<'NODE'
const fs=require('fs'); const CA=process.env.CA; let s=fs.readFileSync(CA,'utf8');
if(s.indexOf('blog_ping')>=0){ console.log('   already hooked — nothing to do'); process.exit(0); }
let n=0;
function one(anchor, insert, where){
  if(s.split(anchor).length-1!==1) throw new Error('anchor not unique: '+anchor.slice(0,60));
  s = (where==='before') ? s.split(anchor).join(insert+anchor) : s.split(anchor).join(anchor+insert);
  n++;
}
// 1) save route — ping when the saved post is published (covers new + edit)
one(
  "return res.redirect('/admin/cstudio/posts/' + postId + '/edit?ok=' + encodeURIComponent('Saved · ' + (status === 'published' ? 'published' : status)));",
  "try { const _bp = require('../lib/blog_ping'); if (status === 'published') _bp.pingPost(pool, _bp.baseFrom(req), { type: p.type, slug: p.slug }); } catch (e) {}\n      ",
  'before'
);
// 2) status route — ping when a post is flipped to published
one(
  "await pool.query('UPDATE cs_posts SET status=$1,published_at=$2,updated_at=now() WHERE id=$3', [to, publishedAt, id]);",
  "\n    try { if (to === 'published') { const _bp = require('../lib/blog_ping'); const _r = (await pool.query('SELECT type,slug FROM cs_posts WHERE id=$1', [id])).rows[0]; if (_r) _bp.pingPost(pool, _bp.baseFrom(req), { type: _r.type, slug: _r.slug }); } } catch (e) {}",
  'after'
);
// 3) delete route — ping the removed URL so engines recrawl and drop it
one(
  "const ex = (await pool.query('SELECT slug,type,status FROM cs_posts WHERE id=$1', [id])).rows[0];",
  "\n    try { if (ex && ex.status === 'published') { const _bp = require('../lib/blog_ping'); _bp.pingPost(pool, _bp.baseFrom(req), { type: ex.type, slug: ex.slug }); } } catch (e) {}",
  'after'
);
fs.writeFileSync(CA,s); console.log('   csAdmin.js: '+n+' hooks added');
NODE

echo "==> checks"
node --check "$CA"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health FAILED"; false; }
trap - ERR
echo "   healthy on :$PORT"
echo "DONE — publishing a post now pings IndexNow instantly. Backups: $BAKDIR"
