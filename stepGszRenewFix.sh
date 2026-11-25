#!/usr/bin/env bash
# stepGszRenewFix — fix galaxyzayron renewals. Root cause: the renew username was captured WITH HTML markup
# (<span ...>88124259</span>), so the reseller bot "could not load line details" and every renewal failed, falling
# back to a fresh FAMILY line (bot_type null). Fixes: (1) strip HTML from username/raw/version at capture + submit so
# the renewal succeeds; (2) carry the chosen content type into the fresh-line fallback so Adult stays Adult; (3) drop
# the customer 'whatsapp' from the renew payload so the reseller bot stops messaging the customer (the website already
# sends its own premium delivered message; owner alerts unaffected). IPTV success path otherwise unchanged.
# Safe: backup + single-match + revert + node --check + health loop on / (==200).
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/checkout.js "$B/"
revert(){ cp "$B/checkout.js" routes/checkout.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- E1: capture (strip HTML) ---
cat > "$T/e1_o" <<'O'
          if (_rl && _rl.username) renewLine = { username: String(_rl.username).slice(0,120), raw: String(_rl.raw||'').slice(0,4000), version: String(_rl.version||'family').slice(0,24), sku: String(_rl.sku||'').slice(0,40) };
O
cat > "$T/e1_n" <<'O'
          if (_rl && _rl.username) renewLine = { username: String(_rl.username).replace(/<[^>]*>/g,'').replace(/\s+/g,' ').trim().slice(0,120), raw: String(_rl.raw||'').replace(/<[^>]*>/g,'').slice(0,4000), version: String(_rl.version||'family').replace(/<[^>]*>/g,'').trim().toLowerCase().slice(0,24), sku: String(_rl.sku||'').replace(/<[^>]*>/g,'').trim().slice(0,40) };
O

# --- E2: renew call (clean username/raw/version at submit; drop whatsapp) ---
cat > "$T/e2_o" <<'O'
          const _rl = _ofR.renew_line;
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            sku: o.bot_sku,
            username: _rl.username,
            raw: _rl.raw || '',
            plan_key: o.bot_plan_key,
            version: _rl.version || 'family',
            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, '')
          });
O
cat > "$T/e2_n" <<'O'
          const _rl = _ofR.renew_line;
          const _ru = String(_rl.username || '').replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim();
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            sku: o.bot_sku,
            username: _ru,
            raw: String(_rl.raw || '').replace(/<[^>]*>/g, ''),
            plan_key: o.bot_plan_key,
            version: String(_rl.version || 'family').replace(/<[^>]*>/g, '').trim().toLowerCase()
          });
O

# --- E3: fallback carries the chosen content type into the fresh line ---
cat > "$T/e3_o" <<'O'
        try { if (o.fields && typeof o.fields === 'object') { delete o.fields.renew_line; await pool.query("UPDATE orders SET fields=$1 WHERE id=$2", [JSON.stringify(o.fields), o.id]); } } catch (e) {}
O
cat > "$T/e3_n" <<'O'
        try {
          const _rv = String((_ofR.renew_line && _ofR.renew_line.version) || '').replace(/<[^>]*>/g, '').trim().toLowerCase();
          if (o.fields && typeof o.fields === 'object') { delete o.fields.renew_line; await pool.query("UPDATE orders SET fields=$1 WHERE id=$2", [JSON.stringify(o.fields), o.id]); }
          if (_rv && _rv !== 'family' && !o.bot_type) { await pool.query("UPDATE orders SET bot_type=$1 WHERE id=$2", [_rv, o.id]); o.bot_type = _rv; }
        } catch (e) {}
O

# --- E4: renew_of call (drop whatsapp) ---
cat > "$T/e4_o" <<'O'
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            order_no: _ofR.renew_of,
            sku: o.bot_sku,
            plan_key: o.bot_plan_key,
            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, ''),
            email: _ofR.act_email || o.email || ''
          });
O
cat > "$T/e4_n" <<'O'
          const rr = await botapi.renew({
            renewal_id: 'ren-' + o.order_no,
            order_no: _ofR.renew_of,
            sku: o.bot_sku,
            plan_key: o.bot_plan_key,
            email: _ofR.act_email || o.email || ''
          });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('routes/checkout.js','utf8');
for(const [o,n] of [['e1_o','e1_n'],['e2_o','e2_n'],['e3_o','e3_n'],['e4_o','e4_n']]){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' matched x'+c);process.exit(5);} s=s.split(O).join(N); }
fs.writeFileSync('routes/checkout.js',s); console.log('routes/checkout.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; cp "$B/checkout.js" routes/checkout.js; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/checkout.js || { echo "syntax error - reverting"; cp "$B/checkout.js" routes/checkout.js; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: renew username HTML-cleaned (renewals will now match the line), Adult carried into fallback, reseller bot no longer messages the customer. gsz http=${HC}"
