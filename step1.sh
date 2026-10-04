#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 1: isolated foundation
#  RUN ON: RETAIL VPS  143.198.209.68  (the galaxytools.net box)
#  Creates ONLY: /opt/gsz , database "gsz" , role "gsz_user" ,
#                PM2 process "gsz" on port 3600.
#  Touches NOTHING else. Does NOT restart any bot or other app.
# ============================================================
set -euo pipefail

APP=/opt/gsz
DBNAME=gsz
DBUSER=gsz_user

echo "== Galaxy Subz x Zayron — Step 1 =="

[ -e "$APP" ] && { echo "ABORT: $APP already exists — nothing done."; exit 1; }
command -v node >/dev/null 2>&1 || { echo "ABORT: node not found"; exit 1; }
command -v npm  >/dev/null 2>&1 || { echo "ABORT: npm not found"; exit 1; }
command -v psql >/dev/null 2>&1 || { echo "ABORT: psql not found"; exit 1; }
command -v pm2  >/dev/null 2>&1 || { echo "ABORT: pm2 not found"; exit 1; }
PORT=""
for cand in 3600 3700 3800 3900 5300 5600 5900 6300 6700; do
  ss -ltnH 2>/dev/null | awk '{print $4}' | grep -q ":$cand$" && continue
  PORT=$cand; break
done
[ -z "$PORT" ] && { echo "ABORT: no free port found — nothing done."; exit 1; }
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DBNAME'" | grep -q 1; then
  echo "ABORT: database $DBNAME already exists — nothing done."; exit 1
fi
echo "[ok] guards passed · auto-selected free port $PORT · db $DBNAME absent"

DBPASS=$(openssl rand -hex 24)
SECRET=$(openssl rand -hex 32)

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DBUSER'" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "ALTER ROLE $DBUSER LOGIN PASSWORD '$DBPASS';"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE $DBUSER LOGIN PASSWORD '$DBPASS';"
fi
sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DBNAME OWNER $DBUSER;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DBNAME" -c "ALTER SCHEMA public OWNER TO $DBUSER;"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "$DBNAME" -c "GRANT ALL ON SCHEMA public TO $DBUSER;"
echo "[ok] database '$DBNAME' + role '$DBUSER' created"

mkdir -p "$APP"/{db,public/img,views,routes,lib}
cd "$APP"

cat > "$APP/package.json" <<'GSZ_PKG_EOF'
{
  "name": "gsz",
  "version": "0.1.0",
  "private": true,
  "description": "Galaxy Subz x Zayron storefront",
  "main": "server.js",
  "scripts": { "start": "node server.js", "seed": "node db/seed.js" },
  "dependencies": {
    "compression": "^1.7.4",
    "dotenv": "^16.4.5",
    "ejs": "^3.1.10",
    "express": "^4.19.2",
    "express-session": "^1.18.0",
    "helmet": "^7.1.0",
    "morgan": "^1.10.0",
    "pg": "^8.12.0"
  }
}
GSZ_PKG_EOF

cat > "$APP/.env" <<GSZ_ENV_EOF
NODE_ENV=production
PORT=${PORT}
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=${DBNAME}
DB_USER=${DBUSER}
DB_PASS=${DBPASS}
SESSION_SECRET=${SECRET}
WA_NUMBER=923141892712
SITE_DOMAIN=galaxyzayron.store
GSZ_ENV_EOF
chmod 600 "$APP/.env"

cat > "$APP/db/schema.sql" <<'GSZ_SCHEMA_EOF'
CREATE TABLE IF NOT EXISTS settings ( key text PRIMARY KEY, value text );
CREATE TABLE IF NOT EXISTS categories (
  id serial PRIMARY KEY, slug text UNIQUE NOT NULL, name text NOT NULL,
  tag text, glyph text, sort int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now() );
CREATE TABLE IF NOT EXISTS products (
  id serial PRIMARY KEY, slug text UNIQUE NOT NULL,
  category_id int REFERENCES categories(id) ON DELETE SET NULL,
  name text NOT NULL, short_desc text, delivery text,
  rating numeric(2,1), orders_count int,
  active boolean NOT NULL DEFAULT true, hidden boolean NOT NULL DEFAULT false,
  sort int NOT NULL DEFAULT 0, created_at timestamptz NOT NULL DEFAULT now() );
CREATE TABLE IF NOT EXISTS product_plans (
  id serial PRIMARY KEY, product_id int NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  label text NOT NULL, price_pkr numeric(12,2) NOT NULL DEFAULT 0,
  old_pkr numeric(12,2), sort int NOT NULL DEFAULT 0 );
CREATE TABLE IF NOT EXISTS banners (
  id serial PRIMARY KEY, category_slug text,
  device text NOT NULL CHECK (device IN ('desktop','mobile')),
  filename text NOT NULL, title text, sort int NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true );
CREATE TABLE IF NOT EXISTS reviews (
  id serial PRIMARY KEY, author text, location text, stars int NOT NULL DEFAULT 5,
  body text, approved boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now() );
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_plans_product ON product_plans(product_id);
GSZ_SCHEMA_EOF

cat > "$APP/server.js" <<'GSZ_SERVER_EOF'
require('dotenv').config();
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const session = require('express-session');
const { Pool } = require('pg');
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT,
  database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS, max: 10 });
const app = express();
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(morgan('tiny'));
app.use('/static', express.static(path.join(__dirname, 'public')));
app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));
async function counts() {
  const c = await pool.query('SELECT count(*)::int AS n FROM categories');
  const p = await pool.query('SELECT count(*)::int AS n FROM products');
  const b = await pool.query('SELECT count(*)::int AS n FROM banners');
  return { categories: c.rows[0].n, products: p.rows[0].n, banners: b.rows[0].n };
}
app.get('/health', async (req, res) => {
  try { const k = await counts(); res.json({ ok: true, ...k }); }
  catch (e) { res.status(500).json({ ok: false, error: e.message }); }
});
app.get('/', async (req, res) => {
  try {
    const k = await counts();
    res.type('html').send(
      '<!doctype html><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Galaxy Subz x Zayron</title>' +
      '<body style="margin:0;font-family:system-ui,sans-serif;background:#0a0e24;color:#eaf0ff;display:grid;place-items:center;min-height:100vh">' +
      '<div style="text-align:center;padding:24px">' +
      '<h1 style="font-weight:800;letter-spacing:-.02em;margin:0 0 6px">Galaxy Subz × Zayron</h1>' +
      '<p style="color:#9fb0d8;margin:0 0 18px">Foundation online · Step 1</p>' +
      '<p style="font-size:18px;margin:0">' + k.categories + ' categories · ' + k.products + ' products · ' + k.banners + ' banners</p>' +
      '</div></body>'
    );
  } catch (e) { res.status(500).send('DB error: ' + e.message); }
});
const PORT = process.env.PORT || 3600;
app.listen(PORT, '0.0.0.0', () => console.log('[gsz] listening on ' + PORT));
GSZ_SERVER_EOF

cat > "$APP/db/seed.js" <<'GSZ_SEED_EOF'
require('dotenv').config();
const { Pool } = require('pg');
const pool = new Pool({
  host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME,
  user: process.env.DB_USER, password: process.env.DB_PASS
});
const CATS = [
  ['entertainment', 'Entertainment', 'Streaming', 'film', 1],
  ['sports', 'Sports', 'Live sport', 'trophy', 2],
  ['iptv', 'IPTV services', 'Live TV', 'tv', 3],
  ['vpns', 'VPNs', 'Privacy', 'shield', 4],
  ['tools', 'Tools', 'AI & productivity', 'tool', 5],
  ['zoom', 'Zoom accounts', 'Meetings', 'video', 6],
  ['players', 'Player activation', 'Players', 'play', 7],
  ['profiles', 'Profile creator', 'Add-on', 'user', 8],
  ['smm', 'SMM services', 'Social growth', 'mega', 9]
];
const P = [
  ['entertainment','Prime Video','1 Month Full',180,0,'Amazon Originals, films & live sport','Instant delivery'],
  ['entertainment','Prime Video','6 Months Full',500,650,'Half a year of Prime in one go','Instant delivery'],
  ['entertainment','HBO Max','1 Month Private Screen',200,0,'Max Originals on your own screen','Private screen'],
  ['entertainment','Disney+','1 Month No Ads',250,0,'Disney, Marvel & Star Wars, ad-free','Shared login'],
  ['entertainment','Hulu','1 Month No Ads',250,0,'US shows & next-day TV, ad-free','Shared login'],
  ['entertainment','Paramount+','USA 1 Month',250,0,'CBS, films & Paramount Originals','Shared login'],
  ['entertainment','Peacock TV','1 Month No Ads',200,0,'NBC shows, films & live events','Shared login'],
  ['entertainment','Hilal Play','1 Month User',300,0,'Family & Islamic entertainment','Instant delivery'],
  ['entertainment','BritBox','USA 1 Month',250,0,'British box sets & classics','Shared login'],
  ['entertainment','Zee5','India 1 Month',100,0,'Hindi films, shows & originals','OTP login'],
  ['entertainment','Crave','Canada 1 Month',350,0,'HBO & Canadian premium TV','Shared login'],
  ['entertainment','ShemarooMe','1 Month User',150,0,'Bollywood & regional cinema','Instant delivery'],
  ['entertainment','KableOne','Punjabi 1 Month',150,0,'Punjabi channels, films & music','Instant delivery'],
  ['entertainment','Eros Now','1 Month User',150,0,'Bollywood library & originals','Instant delivery'],
  ['entertainment','AMC+','1 Month User',400,0,'AMC dramas & cult favourites','Shared login'],
  ['entertainment','StarZ','USA 1 Month',300,0,'Movies & Starz Original series','Shared login'],
  ['entertainment','Hotstar','Canada',200,0,'Indian sport, shows & movies','Shared login'],
  ['entertainment','Tabii','Turkish 1 Month',350,0,'Turkish dramas & live TV','Shared login'],
  ['entertainment','KOCOWA+','Korean 1 Month',400,0,'K-dramas & variety, subtitled','Shared login'],
  ['entertainment','MGM+','1 Month User',350,0,'MGM films & premium series','Shared login'],
  ['entertainment','Hallmark+','1 Month User',350,0,'Feel-good films & series','Shared login'],
  ['entertainment','Rakuten Viki','1 Month User',350,0,'Asian dramas with subtitles','Shared login'],
  ['entertainment','Curiosity Stream','4K 1 Month',350,0,'Documentaries in crisp 4K','Shared login'],
  ['sports','ESPN+','1 Month User',350,0,'Live sport & exclusive events','Shared login'],
  ['sports','F1 TV','USA 1 Month',350,0,'Every Grand Prix, live & on demand','Shared login'],
  ['iptv','Opplex TV','1 Month',150,0,'Thousands of live channels & VOD','Line in minutes'],
  ['iptv','StarShare TV','1 Month',280,0,'Global channels in HD & 4K','Line in minutes'],
  ['iptv','B1G TV','1 Month',300,0,'Sports-heavy global lineup','Line in minutes'],
  ['iptv','Geo IPTV','1 Month',220,0,'Wide channel list, stable servers','Line in minutes'],
  ['iptv','5G Live / Zain TV','1 Month',350,0,'Live TV on fast servers','Line in minutes'],
  ['iptv','Mega OTT','1 Month',330,400,'Huge VOD & live catalogue','Line in minutes'],
  ['iptv','Rolex TV','1 Month',130,0,'Budget-friendly live channels','Line in minutes'],
  ['iptv','Filex IPTV','1 Month',130,0,'Live TV & movies, low cost','Line in minutes'],
  ['iptv','Boss TV','1 Month',130,0,'Entertainment & sports channels','Line in minutes'],
  ['iptv','Zum TV','Best for Dubai 1 Month',350,0,'Great for Gulf viewers','Line in minutes'],
  ['iptv','Trex OTT','1 Month',600,0,'Premium 8K-ready streams','Line in minutes'],
  ['iptv','Strong 8K','1 Month',600,750,'Top-tier 8K channel pack','Line in minutes'],
  ['vpns','Nord VPN','1 Month Email + Pass',200,0,'Fast, private browsing worldwide','Instant delivery'],
  ['vpns','Surfshark VPN','1 Month 1 Device',200,0,'Secure access, OTP login','OTP login'],
  ['vpns','Mysterium VPN','Residential 1 Month',600,0,'Residential IPs, single user','Private account'],
  ['vpns','Vypr VPN','1 Month User',150,0,'Private browsing, no logs','Instant delivery'],
  ['tools','CapCut','1 Month Full 25-day warranty',500,0,'Pro video editing unlocked','Warranty 25d'],
  ['tools','Envato Elements','Portal access',500,0,'Unlimited creative assets','Portal access'],
  ['tools','Grammarly','1 Month User',150,0,'Writing & grammar, premium','Instant delivery'],
  ['tools','QuillBot','Premium 1 Month',150,0,'Paraphrasing & writing tools','Instant delivery'],
  ['tools','Canva Edu','1 Year Invite',300,0,'Canva Pro features, full year','Email invite'],
  ['tools','Gemini AI Pro','1 Year Invite',1500,2000,'Google Gemini Pro for a year','Email invite'],
  ['tools','PicsArt','1 Month User',200,0,'Photo & design editing, pro','Instant delivery'],
  ['tools','Udemy Premium','Portal access',500,0,'Thousands of paid courses','Portal access'],
  ['tools','SkillShare','1 Month Direct login',200,0,'Creative classes, unlimited','Direct login'],
  ['zoom','Zoom Pro','100 participants 1 Month',1200,0,'Host up to 100, no time limit','Private account'],
  ['zoom','Zoom Pro','300 participants 1 Month',2000,0,'Large meetings up to 300','Private account'],
  ['players','Hot Player','Device activation',1300,0,'Premium player activation','MAC activation'],
  ['players','IBO Player','SOL Device activation',1100,0,'Activate IBO Player by MAC','MAC activation'],
  ['profiles','Prime Video','Profiles / Screens Creator',10,0,'Add profiles & screens instantly','Add-on service'],
  ['profiles','Netflix','Profiles / Screens Creator',30,0,'Create Netflix profiles fast','Add-on service'],
  ['smm','TikTok Post Views','No-refill warranty',40,0,'Boost views on a TikTok post','Social service']
];
const BANNERS = [
  ['entertainment','desktop','banner-entertainment-desktop.jpg','Premium Entertainment Subscriptions',1],
  ['entertainment','mobile','banner-entertainment-mobile.jpg','Premium Entertainment Subscriptions',1],
  ['iptv','desktop','banner-iptv-desktop.jpg','Premium IPTV Services',2],
  ['iptv','mobile','banner-iptv-mobile.jpg','Premium IPTV Services',2],
  ['vpns','desktop','banner-vpn-desktop.jpg','Premium VPN Services',3],
  ['vpns','mobile','banner-vpn-mobile.jpg','Premium VPN Services',3],
  ['tools','desktop','banner-tools-desktop.jpg','Premium AI Tools & Productivity',4],
  ['tools','mobile','banner-tools-mobile.jpg','Premium AI Tools & Productivity',4],
  ['players','desktop','banner-players-desktop.jpg','Premium Player Activations',5],
  ['players','mobile','banner-players-mobile.jpg','Premium Player Activations',5]
];
const SETTINGS = [
  ['site_name', 'Galaxy Subz × Zayron'],
  ['site_domain', 'galaxyzayron.store'],
  ['wa_number', '923141892712'],
  ['tagline', 'Premium digital subscriptions & IPTV, delivered instantly']
];
const REVIEWS = [
  ['Ahmed R.', 'Reseller, Lahore', 5, 'Ordered an IPTV line at 2am and had the login in a couple of minutes. Exactly how it should work.'],
  ['Sana K.', 'Karachi', 5, 'Bought Canva and Grammarly together. Both arrived straight away with a proper invoice.'],
  ['Daniyal M.', 'Dubai', 4, 'Paid with Binance, got my Netflix profile set up fast. Support answered on WhatsApp within minutes.'],
  ['Hooria A.', 'Islamabad', 5, 'Renewed my IPTV without any back and forth. Prices are fair and everything just worked.']
];
function slugify(s) { return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, ''); }
(async () => {
  const c = await pool.connect();
  try {
    await c.query('BEGIN');
    for (const [slug, name, tag, glyph, sort] of CATS) {
      await c.query('INSERT INTO categories(slug,name,tag,glyph,sort) VALUES($1,$2,$3,$4,$5) ON CONFLICT(slug) DO NOTHING', [slug, name, tag, glyph, sort]);
    }
    const cmap = {};
    (await c.query('SELECT id,slug FROM categories')).rows.forEach(r => { cmap[r.slug] = r.id; });
    let i = 0;
    for (const [cat, name, plan, price, old, desc, delivery] of P) {
      i++;
      const slug = slugify(name + ' ' + plan) + '-' + i;
      const r = await c.query('INSERT INTO products(slug,category_id,name,short_desc,delivery,sort) VALUES($1,$2,$3,$4,$5,$6) ON CONFLICT(slug) DO NOTHING RETURNING id', [slug, cmap[cat], name, desc, delivery, i]);
      if (r.rows[0]) {
        await c.query('INSERT INTO product_plans(product_id,label,price_pkr,old_pkr,sort) VALUES($1,$2,$3,$4,1)', [r.rows[0].id, plan, price, old || null]);
      }
    }
    for (const [slug, device, filename, title, sort] of BANNERS) {
      await c.query('INSERT INTO banners(category_slug,device,filename,title,sort) VALUES($1,$2,$3,$4,$5)', [slug, device, filename, title, sort]);
    }
    for (const [k, v] of SETTINGS) {
      await c.query('INSERT INTO settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value', [k, v]);
    }
    for (const [a, loc, s, b] of REVIEWS) {
      await c.query('INSERT INTO reviews(author,location,stars,body,approved) VALUES($1,$2,$3,$4,true)', [a, loc, s, b]);
    }
    await c.query('COMMIT');
    const cc = (await c.query('SELECT count(*)::int AS n FROM categories')).rows[0].n;
    const pc = (await c.query('SELECT count(*)::int AS n FROM products')).rows[0].n;
    const bc = (await c.query('SELECT count(*)::int AS n FROM banners')).rows[0].n;
    console.log('[seed] categories=' + cc + ' products=' + pc + ' banners=' + bc);
  } catch (e) {
    await c.query('ROLLBACK');
    console.error('[seed] FAILED: ' + e.message);
    process.exit(1);
  } finally {
    c.release();
    await pool.end();
  }
})();
GSZ_SEED_EOF

node --check "$APP/server.js"
node --check "$APP/db/seed.js"
echo "[ok] server.js + seed.js parse clean"

npm install --omit=dev --no-audit --no-fund

PGPASSWORD="$DBPASS" psql -h 127.0.0.1 -U "$DBUSER" -d "$DBNAME" -v ON_ERROR_STOP=1 -f "$APP/db/schema.sql" >/dev/null
echo "[ok] schema applied"

node "$APP/db/seed.js"

PC=$(PGPASSWORD="$DBPASS" psql -h 127.0.0.1 -U "$DBUSER" -d "$DBNAME" -tAc "SELECT count(*) FROM products")
CC=$(PGPASSWORD="$DBPASS" psql -h 127.0.0.1 -U "$DBUSER" -d "$DBNAME" -tAc "SELECT count(*) FROM categories")
[ "$PC" = "57" ] || { echo "ABORT: expected 57 products, got $PC"; exit 1; }
[ "$CC" = "9" ]  || { echo "ABORT: expected 9 categories, got $CC"; exit 1; }
echo "[ok] verified in DB: $CC categories, $PC products"

cd "$APP"
pm2 start server.js --name gsz
pm2 save >/dev/null
sleep 1.5

if curl -fsS "http://127.0.0.1:$PORT/health" ; then
  echo ""
  echo "============================================================"
  echo " STEP 1 COMPLETE — Galaxy Subz x Zayron foundation is LIVE"
  echo "   folder:   $APP · database: $DBNAME · pm2 'gsz' · port $PORT"
  echo " Your live systems were not touched."
  echo "============================================================"
else
  echo "HEALTH CHECK FAILED — recent logs:"
  pm2 logs gsz --lines 25 --nostream || true
  exit 1
fi
