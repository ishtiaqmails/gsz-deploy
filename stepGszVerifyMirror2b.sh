#!/usr/bin/env bash
# stepGszVerifyMirror2b — add a "Send the code from the website" toggle to the WhatsApp verification panel
# (/admin/wabot), wired to wa_verify_mode (ON=site_otp, OFF=bot_reverse). Matches the existing toggles; the
# signup/verify flow (step 1) already follows this key. Default OFF = current behavior (no change on deploy).
# Edits routes/wabot.js (2 anchors) + views/admin/wabot.ejs (1 anchor). Safe: backup, single-match + revert,
# node --check, EJS compile-check, health loop.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/wabot.js "$B/"; cp views/admin/wabot.ejs "$B/"
revert(){ cp "$B/wabot.js" routes/wabot.js; cp "$B/wabot.ejs" views/admin/wabot.ejs; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- wabot.js render: add siteCode to toggles ---
cat > "$T/a_o" <<'O'
      toggles: {
        verificationEnabled: wa.wa_verification_enabled === '1',
        requireCheckout: (wa.require_wa_verify || 'on') !== 'off',
        requireTrial: (wa.require_wa_trial || 'on') !== 'off',
        orderNotifications: wa.wa_order_notifications_enabled === '1'
      }
O
cat > "$T/a_n" <<'O'
      toggles: {
        verificationEnabled: wa.wa_verification_enabled === '1',
        requireCheckout: (wa.require_wa_verify || 'on') !== 'off',
        requireTrial: (wa.require_wa_trial || 'on') !== 'off',
        orderNotifications: wa.wa_order_notifications_enabled === '1',
        siteCode: (wa.wa_verify_mode === 'site_otp')
      }
O

# --- wabot.js POST /toggles: save wa_verify_mode ---
cat > "$T/b_o" <<'O'
      await setWa('wa_order_notifications_enabled', on(req.body.orderNotifications) ? '1' : '0');
      res.redirect('/admin/wabot?ok=' + encodeURIComponent('Verification settings saved.'));
O
cat > "$T/b_n" <<'O'
      await setWa('wa_order_notifications_enabled', on(req.body.orderNotifications) ? '1' : '0');
      await setWa('wa_verify_mode', on(req.body.siteCode) ? 'site_otp' : 'bot_reverse');
      res.redirect('/admin/wabot?ok=' + encodeURIComponent('Verification settings saved.'));
O

# --- wabot.ejs: add the 5th toggle row ---
cat > "$T/c_o" <<'O'
    <% row('orderNotifications', toggles.orderNotifications, 'Order notifications via WhatsApp', 'Send order received / paid / delivered messages to customers.'); %>
    <button class="btn btn-p" type="submit" style="margin-top:2px">Save settings</button>
O
cat > "$T/c_n" <<'O'
    <% row('orderNotifications', toggles.orderNotifications, 'Order notifications via WhatsApp', 'Send order received / paid / delivered messages to customers.'); %>
    <% row('siteCode', toggles.siteCode, 'Send the code from the website (zayron.tv style)', 'On: the website sends a 6-digit code to their WhatsApp and they enter it on the site. Off: the customer messages the verification bot (your backup engine).'); %>
    <button class="btn btn-p" type="submit" style="margin-top:2px">Save settings</button>
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/wabot.js', [['a_o','a_n'],['b_o','b_n']]);
patch('views/admin/wabot.ejs', [['c_o','c_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/wabot.js || { echo "syntax error - reverting"; revert; exit 1; }
node -e "require('ejs').compile(require('fs').readFileSync('views/admin/wabot.ejs','utf8'),{filename:'views/admin/wabot.ejs'})" || { echo "EJS compile error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: 'Send the code from the website' toggle added to /admin/wabot (wa_verify_mode). Flip ON to activate site-OTP. gsz http=${HC}"
