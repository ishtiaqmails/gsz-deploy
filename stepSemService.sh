#!/usr/bin/env bash
# Semantic brain — Part 1: run the sidecar service (gsz-sem) under PM2 on 127.0.0.1:3910,
# separate from the store app. Pushes a small sample corpus and tests /match over HTTP.
set -Eeuo pipefail
SEM=/opt/gsz-sem; SRC=/opt/gsz-deploy/libsrc/sem
mkdir -p "$SEM"
cp -f "$SRC/package.json" "$SEM/package.json"
cp -f "$SRC/index.mjs"    "$SEM/index.mjs"
cd "$SEM"
# deps already present from the self-test; install is a no-op if unchanged
npm install --no-audit --no-fund >/dev/null 2>&1 || true

pm2 start index.mjs --name gsz-sem --update-env 2>/dev/null || pm2 restart gsz-sem --update-env
echo "waiting for the model to load…"
for i in $(seq 1 40); do
  r=$(curl -s http://127.0.0.1:3910/health || true)
  echo "$r" | grep -q '"ready":true' && { echo "ready ($i s): $r"; break; }
  sleep 1
done

echo
echo "--- push a sample corpus ---"
curl -s -X POST http://127.0.0.1:3910/reindex -H 'Content-Type: application/json' -d '{
 "products":[
  {"id":26,"name":"Opplex TV IPTV","cat_slug":"iptv","text":"Opplex TV IPTV. IPTV services. Thousands of live channels and VOD, works on Firestick and Smart TV"},
  {"id":58,"name":"Netflix Premium","cat_slug":"entertainment","text":"Netflix Premium. Entertainment. Movies and shows, 4K, multiple profiles"},
  {"id":38,"name":"Nord VPN","cat_slug":"vpns","text":"Nord VPN. VPNs. Fast private secure browsing worldwide"}
 ],
 "faqs":[
  {"id":1,"productId":26,"q":"Does Opplex work on Firestick?","a":"Yes, Opplex works on Firestick, Android TV, iOS and Smart TVs."},
  {"id":2,"productId":null,"q":"How fast is delivery?","a":"Most orders are delivered within minutes after payment is confirmed."},
  {"id":3,"productId":null,"q":"Which payment methods do you accept?","a":"We accept local wallets and bank transfer at checkout."}
 ],
 "categories":[{"slug":"iptv","name":"IPTV services"},{"slug":"entertainment","name":"Entertainment"},{"slug":"vpns","name":"VPNs"}],
 "intents":[
  {"intent":"price","phrase":"how much does it cost"},
  {"intent":"delivery","phrase":"how long until I receive it"},
  {"intent":"payment","phrase":"what ways can I pay"},
  {"intent":"recommend","phrase":"suggest a good one for me"}
 ]
}'; echo
echo
echo "--- match tests (semantic, paraphrased) ---"
for q in "will this play on my amazon stick" "how quick do i get it" "do you take easypaisa" "whats the best netflix option" "i want fast internet privacy"; do
  echo "Q: $q"
  curl -s -X POST http://127.0.0.1:3910/match -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}"; echo; echo
done
pm2 save >/dev/null 2>&1 || true
echo "DONE — gsz-sem is live on 127.0.0.1:3910 (isolated). Next: wire it into the bot with fallback."
