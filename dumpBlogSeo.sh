#!/usr/bin/env bash
# dumpBlogSeo.sh — READ ONLY. Maps the blog system + current SEO plumbing so auto-indexing can
# be wired in without disturbing anything. Small, targeted output.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "===== blog-ish tables + columns ====="
node <<'NODE'
const path=require('path');try{require('/opt/gsz/node_modules/dotenv').config({path:'/opt/gsz/.env'});}catch(e){}
const {Pool}=require('/opt/gsz/node_modules/pg');
const pool=new Pool({host:process.env.DB_HOST,port:Number(process.env.DB_PORT)||5432,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const t=(await pool.query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%blog%' OR table_name ILIKE '%post%' OR table_name ILIKE '%article%') ORDER BY table_name")).rows.map(r=>r.table_name);
  console.log('  tables:', t.join(', ')||'(none found)');
  for(const tb of t){
    const c=(await pool.query("SELECT column_name,data_type FROM information_schema.columns WHERE table_name=$1 ORDER BY ordinal_position",[tb])).rows;
    console.log('  ['+tb+'] '+c.map(x=>x.column_name).join(', '));
    const n=(await pool.query('SELECT count(*)::int n FROM '+tb)).rows[0].n;
    console.log('     rows: '+n);
  }
  await pool.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
NODE

echo
echo "===== route files (which handle blog / sitemap / robots) ====="
grep -rilE "blog|sitemap|robots|indexnow" routes server.js app.js 2>/dev/null | head -20

echo
echo "===== sitemap: how it is built + is blog in it? ====="
f=$(grep -rilE "sitemap" routes server.js app.js 2>/dev/null | head -1); echo "  file: ${f:-none}"
[ -n "${f:-}" ] && grep -nE "sitemap|blog|geo_pages|loc>|<url>|SITE_URL|res.type" "$f" | head -25

echo
echo "===== IndexNow: current key + ping function (to reuse for blogs) ====="
grep -rnE "indexnow|IndexNow|INDEXNOW|api.indexnow|/indexnow" lib routes 2>/dev/null | head -15
grep -rilE "indexnow" "$GSZ" 2>/dev/null | grep -vE "node_modules" | head -10

echo
echo "===== robots.txt handling ====="
grep -rnE "robots\.txt|Disallow|User-agent|Sitemap:" routes server.js app.js public 2>/dev/null | head -12

echo
echo "===== blog routes: how a post URL is formed ====="
bf=$(grep -rilE "blog" routes 2>/dev/null | head -1); echo "  file: ${bf:-none}"
[ -n "${bf:-}" ] && grep -nE "router\.(get|post)|slug|/blog|status|published" "$bf" | head -25
