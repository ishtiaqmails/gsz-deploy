#!/usr/bin/env bash
# stepBotMsgProbe.sh — READ-ONLY. Find where the reseller-bot delivery message
# ("Order Delivered!", "Thank you for your purchase!") is produced: is it inside /opt/gsz
# (a live file we can premium-ify here) or sent by the separate reseller bot?
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== search ALL of /opt/gsz (incl. live routes) for the bot-delivery message ==="
grep -rniE "Order Delivered|Thank you for your purchase|📌|Profile Lock|message to bot OTP" --include=*.js --include=*.ejs . 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -20

echo ""
echo "=== how GSZ submits/receives from the reseller bot (delivery relay?) ==="
grep -rlniE "bot_sku|reseller|8095|/send|bot.*deliver|deliver.*bot|submit.?order|botResult|delivery_payload" --include=*.js routes lib 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head
echo "--- key lines ---"
grep -rniE "bot_sku|wa_bot_send_url|8095|submitOrder|botSubmit|delivered_credentials *=|from the bot|bot delivers" --include=*.js routes lib 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -20

echo ""
echo "=== does a GSZ webhook RECEIVE delivery from the bot? ==="
grep -rniE "webhook|/bot/|/api/bot|inbound|callback|order.*complete|mark.*deliver" --include=*.js routes 2>/dev/null | grep -v node_modules | grep -v '\.bak' | head -15
