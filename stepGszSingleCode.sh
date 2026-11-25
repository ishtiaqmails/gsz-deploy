#!/usr/bin/env bash
# stepGszSingleCode — stop the DOUBLE verification code. In site_otp, signup was also firing the legacy step-1
# sendWaCode (a 2nd code in the customer_tokens store the Hub can't verify) and redirecting to the dead
# /account/verify-whatsapp page. This makes signup go straight to /account (the Hub sends the single correct code
# on "Verify now"), and neutralises the legacy GET page so it can never render or send a 2nd code. bot_reverse
# unaffected. Safe: backup, single-match + revert, node --check, health loop on / (==200).
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/account.js "$B/"
revert(){ cp "$B/account.js" routes/account.js; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- A: signup no longer sends a code or routes to the legacy page (Hub handles site_otp) ---
cat > "$T/a_o" <<'O'
      let _waNext = '/account';
      try { if ((await waVerifyMode()) === 'site_otp' && c.wa_number) { await sendWaCode(c); _waNext = '/account/verify-whatsapp'; } } catch (e) {}
      if (ajax) return res.json({ ok:true, redirect: _waNext });
      res.redirect(_waNext);
O
cat > "$T/a_n" <<'O'
      const _waNext = '/account';
      // Site-OTP verification is handled entirely by the Hub modal (one code, one store). Do NOT send a
      // code or route to the legacy page here, or the customer receives two codes from two stores.
      if (ajax) return res.json({ ok:true, redirect: _waNext });
      res.redirect(_waNext);
O

# --- B: legacy GET /account/verify-whatsapp page never renders — bounce to the Hub ---
cat > "$T/b_o" <<'O'
    res.render('account/verify_whatsapp', Object.assign(await shell(), { title:'Verify your WhatsApp', error:null, sent:req.query.sent==='1', wa:(c.wa_number||'') }));
O
cat > "$T/b_n" <<'O'
    return res.redirect('/account');
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' matched x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/account.js', [['a_o','a_n'],['b_o','b_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/account.js || { echo "syntax error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: double code removed. Signup -> /account; the Hub sends ONE code via /start, verified by /verify. Legacy page retired. gsz http=${HC}"
