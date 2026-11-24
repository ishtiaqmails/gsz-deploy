#!/usr/bin/env bash
# READ-ONLY. galaxyzayron base URL/port + does summary.json work with zayron's slugs + counts shape.
G=/opt/gsz
echo "### gsz port / site url ###"
grep -oE "PORT=[0-9]+|SITE_URL=[^ ]+|BASE_URL=[^ ]+|PUBLIC_URL=[^ ]+" "$G/.env" 2>/dev/null
grep -nE "listen\(|process.env.PORT" "$G/server.js" 2>/dev/null | head -3
echo
echo "### pm2 processes (name + port hints) ###"
pm2 jlist 2>/dev/null | node -e "let b='';process.stdin.on('data',d=>b+=d);process.stdin.on('end',()=>{try{JSON.parse(b).forEach(p=>console.log(p.name,'| port env:',(p.pm2_env&&p.pm2_env.env&&p.pm2_env.env.PORT)||'?','| cwd:',(p.pm2_env&&p.pm2_env.pm_cwd)||'?'))}catch(e){console.log('(pm2 parse failed)')}})" 2>/dev/null || echo "(pm2 jlist n/a)"
echo
echo "### try summary.json on localhost for zayron slugs (find gsz port automatically) ###"
GPORT=$(grep -oE "PORT=[0-9]+" "$G/.env" 2>/dev/null | head -1 | grep -oE "[0-9]+")
echo "guessed gsz PORT=$GPORT"
for slug in opplex-tv-iptv starshare-tv-iptv filex-tv-iptv b1g-tv-iptv; do
  echo "--- $slug ---"
  curl -s --max-time 5 "http://127.0.0.1:${GPORT}/iptv/${slug}/summary.json" | head -c 300
  echo
done
echo
echo "### gsz products: slug <-> sku <-> name (to map zayron bot_sku) ###"
grep -rnE "slug|sku|iptv_panel" "$G/lib/storefront.js" 2>/dev/null | head -10
echo DONE
