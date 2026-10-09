#!/usr/bin/env bash
# dumpVerify — what the Verification Bot (gszwabot) + site webhook currently handle,
# and whether any owner-only (inventory/stock/admin) command path exists yet.
echo "########## 1. gsz-wabot presence + files ##########"
ls -la /opt/gsz-wabot 2>&1 | head -30
echo "--- src ---"; ls -la /opt/gsz-wabot/src 2>/dev/null | head -30
echo
echo "########## 2. gszwabot — owner/command/inventory handling (grep) ##########"
grep -rnE "owner|OWNER|admin|ADMIN|inventory|stock|command|cmd|incoming|webhook|from|sender|jid" /opt/gsz-wabot --include=*.js 2>/dev/null | grep -v node_modules | head -50
echo
echo "########## 3. site incoming webhook (routes/whatsapp.js) — owner/command path? ##########"
grep -nE "incoming|owner|OWNER|admin|inventory|stock|command|cmd|verify|otp|code|identity" /opt/gsz/routes/whatsapp.js 2>/dev/null | head -60
echo
echo "########## 4. any owner/bot-command module in the site ##########"
grep -rlnE "owner.?command|ownerCommand|botCommand|/inventory|manageStock|addStock" /opt/gsz/routes /opt/gsz/lib 2>/dev/null | grep -v node_modules | head
echo
echo "########## 5. config: owner number + wabot wiring (.env, masked) ##########"
grep -iE "OWNER|ADMIN|WABOT|GSZ_WA|WHATSAPP|WA_" /opt/gsz/.env 2>/dev/null | sed -E 's/(KEY|TOKEN|SECRET|PASS|WEBHOOK)=.*/\1=***/I'
echo
echo "########## 6. processes ##########"
pm2 list 2>/dev/null | grep -iE "gsz|wabot|Name" || true
echo "== dumpVerify done =="
