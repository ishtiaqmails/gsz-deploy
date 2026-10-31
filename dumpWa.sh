#!/usr/bin/env bash
set -uo pipefail
GSZ=/opt/gsz
sec(){ echo; echo "========== $* =========="; }

sec "A) routes/wabot.js — website's bot status/qr/page (FULL)"
cat "$GSZ/routes/wabot.js" 2>/dev/null | sed -n '1,220p'

sec "B) routes/whatsapp.js — verification handler (/internal/whatsapp/incoming, how a customer becomes verified) FULL"
cat "$GSZ/routes/whatsapp.js" 2>/dev/null | sed -n '1,260p'

sec "C) how the bot send-API + secret are called from the site (lib/botapi.js exports + status/send)"
grep -nE "module.exports|function |BOT_PORT|8095|/status|/send|/logout|/reconnect|wa_bot_webhook_secret|x-wa-secret|qrcode" "$GSZ/lib/botapi.js" 2>/dev/null | head -40

sec "D) current WhatsApp gating in checkout + trials (where to wire the toggles)"
grep -nE "waOk|wa_verified|verified|whatsapp|require.*wa|wa_required|otp|verify" "$GSZ/routes/checkout.js" "$GSZ/routes/trials.js" 2>/dev/null | head -40

sec "E) wa_settings keys in use across the code (the settings model)"
grep -rhoE "wa_settings WHERE key='[a-z_]+'|wa_settings.*key='[a-z_]+'|key='wa_[a-z_]+'|'wa_[a-z_]+'" "$GSZ/routes" "$GSZ/lib" 2>/dev/null | grep -oE "wa_[a-z_]+|require[_a-z]*" | sort -u | head -40
