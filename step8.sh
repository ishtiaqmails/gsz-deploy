#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 8: product image upload (admin)
#  RUN: cd /opt/gsz-deploy && git pull && bash step8.sh
#  Adds: products.image column, a per-product image upload in the
#  product editor (with the recommended dimension shown), and a
#  logo dimension note on the Branding page.
#  Upload-first: display on cards/pages lands with the redesign step.
#  No changes to pricing, orders, routes or business logic.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/routes" ] || { echo "ABORT: $APP/routes not found — run earlier steps first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"; : "${DB_USER:?}"; : "${DB_NAME:?}"; : "${DB_PASS:?}"
echo "== Galaxy Subz x Zayron — Step 8 (product images) · port $PORT =="
ts=$(date +%s)
PSQL(){ PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" "$@"; }

cp -a "$APP/server.js"                        "$APP/server.js.bak-step8.$ts"
cp -a "$APP/views/admin/product_edit.ejs"     "$APP/views/admin/product_edit.ejs.bak-step8.$ts"
cp -a "$APP/views/admin/branding.ejs"         "$APP/views/admin/branding.ejs.bak-step8.$ts"

restore(){
  echo ">> rolling back Step 8"
  cp -a "$APP/server.js.bak-step8.$ts"                    "$APP/server.js"
  cp -a "$APP/views/admin/product_edit.ejs.bak-step8.$ts" "$APP/views/admin/product_edit.ejs"
  cp -a "$APP/views/admin/branding.ejs.bak-step8.$ts"     "$APP/views/admin/branding.ejs"
  rm -f "$APP/routes/adminProductImage.js"
  pm2 restart gsz >/dev/null 2>&1 || true
}

# ---------- 1. schema ----------
PSQL -v ON_ERROR_STOP=1 <<'GSZ_SQL_EOF'
ALTER TABLE products ADD COLUMN IF NOT EXISTS image text;
GSZ_SQL_EOF
echo "[ok] schema: products.image ready"

# ---------- 2. route: product image upload ----------
cat > "$APP/routes/adminProductImage.js" <<'GSZ_PI_EOF'
const path = require('path');
const fs = require('fs');
const express = require('express');
const multer = require('multer');

module.exports = function (pool) {
  const router = express.Router();
  const IMG = path.join(__dirname, '..', 'public', 'img');
  fs.mkdirSync(IMG, { recursive: true });

  const storage = multer.diskStorage({
    destination: (q, f, cb) => cb(null, IMG),
    filename: (q, f, cb) => cb(null, 'prod_' + Date.now() + '_' + Math.random().toString(36).slice(2, 7) + path.extname(f.originalname || '').toLowerCase())
  });
  const okf = /\.(jpg|jpeg|png|webp|gif|svg)$/i;
  const upload = multer({ storage, limits: { fileSize: 12 * 1024 * 1024 }, fileFilter: (q, f, cb) => cb(null, okf.test(f.originalname || '')) });

  function auth(req, res, next) { if (req.session && req.session.admin) return next(); return res.redirect('/admin/login'); }

  router.post('/products/:id/image', auth, upload.single('image'), async (req, res) => {
    try {
      if (!req.file) return res.redirect('/admin/products/' + req.params.id + '/edit?ok=Choose+an+image+file');
      await pool.query('UPDATE products SET image=$1 WHERE id=$2', [req.file.filename, req.params.id]);
      res.redirect('/admin/products/' + req.params.id + '/edit?ok=Image+updated');
    } catch (e) { res.status(500).send('Image upload failed: ' + e.message); }
  });

  router.post('/products/:id/image/remove', auth, express.urlencoded({ extended: false }), async (req, res) => {
    try {
      await pool.query('UPDATE products SET image=NULL WHERE id=$1', [req.params.id]);
      res.redirect('/admin/products/' + req.params.id + '/edit?ok=Image+removed');
    } catch (e) { res.status(500).send('Remove failed: ' + e.message); }
  });

  return router;
};
GSZ_PI_EOF
echo "[ok] route: adminProductImage.js written"

# ---------- 3. mount in server.js (exact-string) ----------
cat > /tmp/gsz8_server.js <<'GSZ_S8_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
if(s.indexOf('adminProductImage')!==-1){console.log('server already patched');process.exit(0);}
const anchor="const adminOrdersRouter = require('./routes/adminOrders')(pool);\napp.use('/admin', adminOrdersRouter);";
const parts=s.split(anchor);
if(parts.length!==2){console.error('server anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
const add=anchor+"\n\nconst adminProductImageRouter = require('./routes/adminProductImage')(pool);\napp.use('/admin', adminProductImageRouter);";
s=parts.join(add);
fs.writeFileSync(f,s);
console.log('server.js patched');
GSZ_S8_EOF
node /tmp/gsz8_server.js "$APP/server.js" || { restore; exit 1; }

# ---------- 4. product editor: image card (exact-string) ----------
cat > /tmp/gsz8_editor.js <<'GSZ_E8_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
if(s.indexOf('Product image')!==-1){console.log('editor already patched');process.exit(0);}
const anchor='<form method="post" action="/admin/products/save">';
const parts=s.split(anchor);
if(parts.length!==2){console.error('editor anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
const card=[
'<% if (prod) { %>',
'<div class="card">',
'  <h2>Product image</h2>',
'  <p class="hint">Shown on the product card and product page. Recommended: <b>800 × 800 px</b> (square) — PNG, JPG or WebP.</p>',
'  <% if (prod.image) { %>',
'    <img src="/static/img/<%= prod.image %>?v=<%= Date.now() %>" style="width:120px;height:120px;object-fit:cover;border-radius:12px;border:1px solid var(--hair);margin-bottom:12px;display:block">',
'  <% } else { %>',
'    <div style="width:120px;height:120px;border-radius:12px;background:repeating-linear-gradient(45deg,#eef2fe,#eef2fe 8px,#e3e8f6 8px,#e3e8f6 16px);display:grid;place-items:center;color:var(--muted);font-size:12px;margin-bottom:12px">No image</div>',
'  <% } %>',
'  <form method="post" action="/admin/products/<%= prod.id %>/image" enctype="multipart/form-data">',
'    <input type="file" name="image" accept="image/*" required style="font-size:13px;margin-bottom:10px">',
'    <div><button class="btn btn-p" type="submit"><%= prod.image ? \'Replace image\' : \'Upload image\' %></button></div>',
'  </form>',
'  <% if (prod.image) { %>',
'  <form method="post" action="/admin/products/<%= prod.id %>/image/remove" style="margin-top:8px"><button class="btn btn-g" style="color:#b42318" type="submit">Remove image</button></form>',
'  <% } %>',
'</div>',
'<% } else { %>',
'<div class="card"><h2>Product image</h2><p class="hint">Save the product first, then re-open it to upload its image (recommended 800 × 800 px).</p></div>',
'<% } %>',
''].join('\n');
s=parts.join(card+anchor);
fs.writeFileSync(f,s);
console.log('product_edit.ejs patched');
GSZ_E8_EOF
node /tmp/gsz8_editor.js "$APP/views/admin/product_edit.ejs" || { restore; exit 1; }

# ---------- 5. branding: logo dimension note (exact-string) ----------
cat > /tmp/gsz8_brand.js <<'GSZ_B8_EOF'
const fs=require('fs'); const f=process.argv[2];
let s=fs.readFileSync(f,'utf8');
if(s.indexOf('Recommended size')!==-1){console.log('branding already patched');process.exit(0);}
const anchor='<p class="hint">Transparent PNG or SVG works best. Shown in the header and footer.</p>';
const parts=s.split(anchor);
if(parts.length!==2){console.error('branding anchor count='+(parts.length-1)+' (want 1)');process.exit(1);}
const repl='<p class="hint">Transparent PNG or SVG works best. Shown in the header and footer. Recommended size: <b>240 × 64 px</b> (wide) — or any transparent logo; it scales to fit.</p>';
s=parts.join(repl);
fs.writeFileSync(f,s);
console.log('branding.ejs patched');
GSZ_B8_EOF
node /tmp/gsz8_brand.js "$APP/views/admin/branding.ejs" || { restore; exit 1; }

# ---------- 6. validate ----------
node --check "$APP/server.js"                     || { restore; exit 1; }
node --check "$APP/routes/adminProductImage.js"   || { restore; exit 1; }
echo "[ok] JS parses clean"

cat > "$APP/_gsz8_render.js" <<'GSZ_R8_EOF'
const ejs=require('ejs');
const V=process.argv[2]+'/views/';
const prod={id:5,name:'Netflix',slug:'netflix',category_id:3,short_desc:'s',delivery:'Instant',long_desc:'L',hidden:false,image:'prod_x.png'};
const cats=[{id:3,name:'Entertainment'}];
const jobs=[
 ['admin/product_edit.ejs',{prod,cats,plans:[{label:'1 Month',price_pkr:1299,old_pkr:0}],faqs:[]}],
 ['admin/product_edit.ejs',{prod:null,cats,plans:[],faqs:[]}],
 ['admin/product_edit.ejs',{prod:Object.assign({},prod,{image:null}),cats,plans:[],faqs:[]}],
 ['admin/branding.ejs',{flash:null,settings:{logo_file:'logo.png'},slots:[{slug:'iptv',name:'IPTV'}],map:{},dims:{desktop:'1942 × 809 px',mobile:'1536 × 1024 px'}}]
];
(async()=>{let bad=0;for(const [f,d] of jobs){try{await ejs.renderFile(V+f,d,{});console.log('OK   '+f);}catch(e){console.log('FAIL '+f+' -> '+e.message);bad++;}}process.exit(bad?1:0);})();
GSZ_R8_EOF
node "$APP/_gsz8_render.js" "$APP" || { rm -f "$APP/_gsz8_render.js"; restore; exit 1; }
rm -f "$APP/_gsz8_render.js"
echo "[ok] admin views render (editor: edit + new + no-image; branding)"

# prove the column really exists
HASCOL=$(PSQL -tAc "SELECT count(*) FROM information_schema.columns WHERE table_name='products' AND column_name='image'" | tr -d '[:space:]')
[ "$HASCOL" = "1" ] || { echo "FAIL: products.image column missing"; restore; exit 1; }
echo "[ok] products.image column present"

pm2 restart gsz --update-env >/dev/null
sleep 1.6

PID=$(PSQL -tAc "SELECT id FROM products ORDER BY sort,id LIMIT 1" | tr -d '[:space:]')
EDIT=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin/products/$PID/edit")
IMGPOST=$(curl -s -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:$PORT/admin/products/$PID/image")
HEALTH=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/health")

OKALL=1
[ "$EDIT" = "302" ] || [ "$EDIT" = "200" ]        || { echo "FAIL: product editor route (HTTP $EDIT)"; OKALL=0; }
[ "$IMGPOST" = "302" ]                             || { echo "FAIL: image upload route not gated/mounted (HTTP $IMGPOST)"; OKALL=0; }
[ "$HEALTH" = "200" ]                              || { echo "FAIL: site health (HTTP $HEALTH)"; OKALL=0; }

if [ "$OKALL" != "1" ]; then
  echo "CHECK FAILED — rolling back Step 8"; restore; pm2 logs gsz --lines 25 --nostream || true; exit 1
fi

echo "============================================================"
echo " STEP 8 COMPLETE — product image upload is live"
echo "   Admin → Products → open any product → 'Product image' card"
echo "   (recommended 800 × 800 px). Logo note added on Branding."
echo "   Upload your product artwork now; it appears on the storefront"
echo "   with the next step (card + homepage redesign)."
echo "============================================================"
