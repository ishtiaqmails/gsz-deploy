# GSZ Verification Bot

Dedicated WhatsApp **verification** bot for the Galaxy Subz × Zayron site.
It is NOT the Galaxy reseller bot — run it on its own number and process.

## What it does
- Receives customer messages, extracts their WhatsApp LID / phone, and forwards
  them to the website webhook (`/internal/whatsapp/incoming`, secret-gated).
- Replies with whatever the website returns (verification result, or a throttled
  support redirect for non-verification chatter).
- Exposes a small secret-gated send API (`POST /send`, `GET /health`) so the
  website can push order/credential notifications.

## Install / run (handled by step79.sh)
1. `bash step79.sh 923XXXXXXXXX`  (your spare verification number)
2. `pm2 logs gszwabot --lines 40` and scan the QR with that number's WhatsApp.
3. When it logs `connected as …`, verification works end-to-end.

## Config (`.env`)
- `WEBSITE_BASE` — the gsz site URL (localhost if same VPS).
- `WA_WEBHOOK_SECRET` — must equal `wa_settings.wa_bot_webhook_secret` (auto-filled).
- `BOT_PORT` — port for the send API (default 8095).
- `UNSUPPORTED_COOLDOWN` — seconds between redirect replies to the same chat.

Delete the `auth/` folder to force a fresh QR login.
