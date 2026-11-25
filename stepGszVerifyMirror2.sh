#!/usr/bin/env bash
# stepGszVerifyMirror2 — admin toggle for wa_verify_mode. Adds a "Verification method" card (Site code |
# Bot message) to /admin/whatsapp + the save route. The signup/verify flow (step 1) already follows this key.
# Edits routes/adminWhatsapp.js (2 anchors) + views/admin/whatsapp.ejs (1 anchor). Safe: backup, single-match +
# auto-revert, node --check, EJS compile-check, health loop.
set -e
G=/opt/gsz; cd "$G"
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "'\''' ); PORT=${PORT:-3900}
TS=$(date +%s); B="$G/.retired/$TS"; mkdir -p "$B"; cp routes/adminWhatsapp.js "$B/"; cp views/admin/whatsapp.ejs "$B/"
revert(){ cp "$B/adminWhatsapp.js" routes/adminWhatsapp.js; cp "$B/whatsapp.ejs" views/admin/whatsapp.ejs; pm2 restart gsz >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# --- adminWhatsapp.js: GET render passes verifyMode ---
cat > "$T/a_o" <<'O'
        requireVerify: c.require_wa_verify !== 'off'
      });
O
cat > "$T/a_n" <<'O'
        requireVerify: c.require_wa_verify !== 'off',
        verifyMode: (c.wa_verify_mode === 'site_otp') ? 'site_otp' : 'bot_reverse'
      });
O

# --- adminWhatsapp.js: add the save route after verify-policy ---
cat > "$T/b_o" <<'O'
    } catch (e) { res.redirect('/admin/whatsapp?ok=' + encodeURIComponent('Could not save policy')); }
  });
O
cat > "$T/b_n" <<'O'
    } catch (e) { res.redirect('/admin/whatsapp?ok=' + encodeURIComponent('Could not save policy')); }
  });

  // Verification method: 'site_otp' (website sends the code, customer enters it) or 'bot_reverse' (customer messages the bot).
  router.post('/whatsapp/verify-mode', auth, body, async (req, res) => {
    try {
      const v = (req.body && req.body.mode === 'site_otp') ? 'site_otp' : 'bot_reverse';
      await pool.query("INSERT INTO wa_settings(key,value) VALUES('wa_verify_mode',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [v]);
      res.redirect('/admin/whatsapp?ok=' + encodeURIComponent(v === 'site_otp' ? 'Saved — website now sends the verification code (site code)' : 'Saved — customers verify by messaging the bot (backup)'));
    } catch (e) { res.redirect('/admin/whatsapp?ok=' + encodeURIComponent('Could not save method')); }
  });
O

# --- whatsapp.ejs: insert the Verification method card before <script> ---
cat > "$T/c_o" <<'O'
    <div class="wa-nsave" style="margin-top:14px"><button class="btn btn-p" type="submit">Save policy</button></div>
  </form>
</div>

<script>
O
cat > "$T/c_n" <<'O'
    <div class="wa-nsave" style="margin-top:14px"><button class="btn btn-p" type="submit">Save policy</button></div>
  </form>
</div>

<div class="card wa-card" style="margin-top:16px">
  <div class="wa-head">
    <span class="wa-logo" style="background:#eef2fb;color:#2a7bff"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg></span>
    <div><div class="wa-htitle">Verification method</div><div class="wa-hsub">How a customer verifies their WhatsApp</div></div>
  </div>
  <form method="post" action="/admin/whatsapp/verify-mode" class="wa-nums">
    <p class="wa-hint">The whole signup and verify flow follows this live. <b>Site code</b> is the zayron.tv-style flow: the website sends a 6-digit code to the customer's WhatsApp and they enter it on the site. <b>Bot message</b> is the original flow where the customer messages the verification bot. Switch back any time.</p>
    <label style="display:flex;align-items:center;gap:10px;font-weight:600;cursor:pointer;color:#1f2a44;margin-bottom:10px">
      <input type="radio" name="mode" value="site_otp" <%= verifyMode === 'site_otp' ? 'checked' : '' %> style="width:18px;height:18px;accent-color:#2a7bff">
      Site code — website sends the code, customer enters it on the site
    </label>
    <label style="display:flex;align-items:center;gap:10px;font-weight:600;cursor:pointer;color:#1f2a44">
      <input type="radio" name="mode" value="bot_reverse" <%= verifyMode !== 'site_otp' ? 'checked' : '' %> style="width:18px;height:18px;accent-color:#2a7bff">
      Bot message — customer messages the verification bot (backup)
    </label>
    <div class="wa-nsave" style="margin-top:14px"><button class="btn btn-p" type="submit">Save method</button></div>
  </form>
</div>

<script>
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
function patch(file, pairs){ let s=fs.readFileSync(file,'utf8'); for(const [o,n] of pairs){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c+' in '+file);process.exit(5);} s=s.split(O).join(N);} fs.writeFileSync(file,s); console.log(file+' PATCHED OK'); }
patch('routes/adminWhatsapp.js', [['a_o','a_n'],['b_o','b_n']]);
patch('views/admin/whatsapp.ejs', [['c_o','c_n']]);
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; revert; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check routes/adminWhatsapp.js || { echo "syntax error - reverting"; revert; exit 1; }
node -e "require('ejs').compile(require('fs').readFileSync('views/admin/whatsapp.ejs','utf8'),{filename:'views/admin/whatsapp.ejs'})" || { echo "EJS compile error - reverting"; revert; exit 1; }
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
HC=000
for i in $(seq 1 15); do sleep 1; HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000); [ "$HC" = "200" ] && break; done
echo "gsz / http=${HC}"
[ "$HC" = "200" ] || { echo "gsz not serving 200 - reverting"; revert; exit 1; }
echo "DONE: admin Verification-method toggle live at /admin/whatsapp. Flip to 'Site code' to activate site-OTP. gsz http=${HC}"
