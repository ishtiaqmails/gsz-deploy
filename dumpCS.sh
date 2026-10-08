#!/usr/bin/env bash
# dumpCS — Content Studio architecture audit: entry/routing, SEO/sitemap/robots,
# media uploads, admin shell/auth, DB schema. Read-only.
GSZ=/opt/gsz; cd "$GSZ"

echo "########## app entry (server) ##########"
ENTRY=$(grep -rln "app.listen\|\.listen(" *.js 2>/dev/null | head -1)
echo "entry file: ${ENTRY:-unknown}"
echo "--- package.json main/scripts ---"; sed -n '1,40p' package.json 2>/dev/null
echo "--- route mounts + middleware (session/static/multer/body) in entry ---"
[ -n "$ENTRY" ] && grep -nE "require\(|app.use|app.set|express.static|session|multer|bodyParser|urlencoded|\.listen" "$ENTRY" | head -80

echo
echo "########## routes/ files ##########"
ls routes/ 2>/dev/null

echo
echo "########## SEO / sitemap / robots ##########"
grep -rln "sitemap\|robots" routes/*.js *.js 2>/dev/null
echo "--- robots.txt / sitemap files in public ---"; ls -la public/ 2>/dev/null | grep -iE "robots|sitemap"
echo "--- meta/OG/canonical/jsonld usage in views (count) ---"
grep -rlnE "og:|twitter:|canonical|application/ld\+json|meta name=.description" views 2>/dev/null

echo
echo "########## media upload (multer) config ##########"
grep -rnE "multer|dest:|diskStorage|/static/img|uploads" routes/*.js *.js 2>/dev/null | head -25
echo "--- static img dir ---"; ls -la public/static 2>/dev/null || ls -la static 2>/dev/null | head

echo
echo "########## admin auth + route registration ##########"
grep -rnE "admin" "$ENTRY" 2>/dev/null | head -30
echo "--- admin auth middleware ---"; grep -rln "req.session.admin\|isAdmin\|adminAuth\|requireAdmin" routes/*.js *.js 2>/dev/null

echo
echo "########## views/admin/_shell_top.ejs (nav) ##########"
sed -n '1,80p' views/admin/_shell_top.ejs 2>/dev/null | cat -n

echo
echo "########## DB: tables + key columns ##########"
NODE_PATH="$GSZ/node_modules" node -e "require('dotenv').config({path:'$GSZ/.env'});const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});(async()=>{const q=async(l,s)=>{try{const r=await p.query(s);console.log('--- '+l+' ---');console.log(JSON.stringify(r.rows));}catch(e){console.log(l+' ERR '+e.message);}};await q('tables','select table_name from information_schema.tables where table_schema=CHRpublicCHR order by table_name'.replace(/CHR/g,String.fromCharCode(39)));await q('products cols','select column_name,data_type from information_schema.columns where table_name=CHRproductsCHR order by ordinal_position'.replace(/CHR/g,String.fromCharCode(39)));await q('categories cols','select column_name,data_type from information_schema.columns where table_name=CHRcategoriesCHR order by ordinal_position'.replace(/CHR/g,String.fromCharCode(39)));await p.end();})();"
