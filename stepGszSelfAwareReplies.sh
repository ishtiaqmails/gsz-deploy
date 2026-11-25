#!/usr/bin/env bash
# stepGszSelfAwareReplies — make the two hardcoded-brand bot templates self-aware now that the Verification Bot is
# shared by galaxyzayron.store + zayron.tv. Both templates switch "galaxyzayron.store" -> {{site_url}}; the webhook
# fills site_url per SENDER: galaxyzayron's own customers get galaxyzayron.store, everyone else (zayron senders) get
# the editable sister_site_url setting (seeded zayron.tv). Sales/support numbers are already shared, so only the URL
# changes. Safe: backup + caller guard + node --check + reversible template update + health loop on / (==200).
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/whatsapp.js "$B/"
PGQ(){ node -e "const {Pool}=require('pg');require('dotenv').config();const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});p.query(process.argv[1]).then(r=>{if(r.rows&&r.rows.length)r.rows.forEach(x=>console.log(JSON.stringify(x)));return p.end();}).catch(e=>{console.error('PGERR',e.message);process.exit(2);});" "$1"; }
revert(){ cp "$B/whatsapp.js" routes/whatsapp.js; PGQ "UPDATE wa_templates SET body=replace(body,'{{site_url}}','galaxyzayron.store') WHERE key IN ('whatsapp.verification_success','whatsapp.redirect_support')" >/dev/null 2>&1 || true; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- guard: these two templates must each be composed in exactly ONE place (the ones we patch) ---
VC=$(grep -rn "watpl.compose(pool, 'whatsapp.verification_success'" routes lib 2>/dev/null | grep -v node_modules | grep -v "\.bak" | wc -l)
RC=$(grep -rn "watpl.compose(pool, 'whatsapp.redirect_support'" routes lib 2>/dev/null | grep -v node_modules | grep -v "\.bak" | wc -l)
echo "callers: verification_success=${VC}  redirect_support=${RC}"
if [ "$VC" != "1" ] || [ "$RC" != "1" ]; then echo "UNEXPECTED extra caller(s) — aborting so no template renders a blank URL. Nothing changed."; grep -rn "whatsapp.verification_success\|whatsapp.redirect_support" routes lib 2>/dev/null | grep -v node_modules | grep -v "\.bak"; rm -rf "$T"; exit 1; fi

# --- whatsapp.js anchor A: verification_success passes site_url (galaxyzayron) ---
cat > "$T/a_o" <<'O'
      const reply = await watpl.compose(pool, 'whatsapp.verification_success', { site_name: 'Galaxy Subz × Zayron' });
O
cat > "$T/a_n" <<'O'
      const reply = await watpl.compose(pool, 'whatsapp.verification_success', { site_name: 'Galaxy Subz × Zayron', site_url: String(s.site_base_url || 'galaxyzayron.store').replace(/^https?:\/\//, '').replace(/\/+$/, '') });
O

# --- whatsapp.js anchor B: redirect_support brands by sender (gsz customer vs zayron) ---
cat > "$T/b_o" <<'O'
      const reply = await watpl.compose(pool, 'whatsapp.redirect_support', { sales_number: s.wa_sales_number, support_number: s.wa_support_number, customer_reference: '' });
      return res.json({ ok: true, action: 'REDIRECT', reply });
O
cat > "$T/b_n" <<'O'
      let _siteUrl = String(s.site_base_url || 'galaxyzayron.store').replace(/^https?:\/\//, '').replace(/\/+$/, '');
      try {
        const _d = String(parts.phone || (parts.pnJid ? String(parts.pnJid).split('@')[0] : '')).replace(/[^0-9]/g, '');
        if (_d && _d.length >= 7) {
          const _isGsz = (await pool.query("SELECT 1 FROM customers WHERE right(regexp_replace(COALESCE(wa_number,''),'[^0-9]','','g'),10)=right($1,10) LIMIT 1", [_d])).rows[0];
          if (!_isGsz) _siteUrl = s.sister_site_url || 'zayron.tv';
        }
      } catch (e) {}
      const reply = await watpl.compose(pool, 'whatsapp.redirect_support', { sales_number: s.wa_sales_number, support_number: s.wa_support_number, customer_reference: '', site_url: _siteUrl });
      return res.json({ ok: true, action: 'REDIRECT', reply });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/whatsapp.js','utf8');
for(const [o,n] of [['a_o','a_n'],['b_o','b_n']]){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c);process.exit(5);} s=s.split(O).join(N); }
fs.writeFileSync('routes/whatsapp.js',s); console.log('routes/whatsapp.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; cp "$B/whatsapp.js" routes/whatsapp.js; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/whatsapp.js || { echo "syntax error - reverting"; cp "$B/whatsapp.js" routes/whatsapp.js; exit 1; }

# --- seed editable sister-site setting (keep user's value if already set) ---
PGQ "INSERT INTO wa_settings(key,value) VALUES('sister_site_url','zayron.tv') ON CONFLICT(key) DO NOTHING" >/dev/null || { echo "seed failed - reverting"; revert; exit 1; }
# --- make both templates self-aware (reversible) ---
PGQ "UPDATE wa_templates SET body=replace(body,'galaxyzayron.store','{{site_url}}') WHERE key IN ('whatsapp.verification_success','whatsapp.redirect_support')" >/dev/null || { echo "template update failed - reverting"; revert; exit 1; }

pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }

echo "--- updated templates ---"
PGQ "SELECT key, body FROM wa_templates WHERE key IN ('whatsapp.verification_success','whatsapp.redirect_support') ORDER BY key"
echo "--- sister_site_url ---"
PGQ "SELECT value FROM wa_settings WHERE key='sister_site_url'"
echo "DONE: replies are now self-aware. galaxyzayron customers -> galaxyzayron.store; others -> sister_site_url (zayron.tv, editable). gsz http=${HC}"
