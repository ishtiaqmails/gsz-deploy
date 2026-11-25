#!/usr/bin/env bash
# diagBotLocate — find the reseller bot + gsz-api bridge code and see how they handle message branding and
# the order 'source' (zayron-web vs gsz_website). READ-ONLY. Touches nothing.
set +e
echo "############ pm2 processes: script paths + cwd ############"
for P in gszwabot gsz-sem galaxy-store gzportal; do
  echo "--- $P ---"
  pm2 describe "$P" 2>/dev/null | grep -E "script path|exec cwd|script args|node args" | head
done
echo
echo "############ where is the gsz-api bridge (GSZ_BOT_API_URL)? ############"
grep -E '^GSZ_BOT_API_URL=' /opt/gsz/.env 2>/dev/null
echo "listening sockets for :8090 / bot ports:"
ss -ltnp 2>/dev/null | grep -E ":8090|:8091|:8092" | head
echo
echo "############ bot dirs under /opt (likely the bot + bridge) ############"
ls -1d /opt/*bot* /opt/*wa* /opt/*store* /opt/*api* 2>/dev/null | head
echo
echo "############ which dirs contain submit-order / source handling / site branding ############"
for D in /opt/galaxystore /opt/galaxy-store /opt/gszwabot /opt/gsz-api /opt/store /opt/bot; do
  [ -d "$D" ] && { echo "=== $D ==="; grep -rln "submit-order\|/api/generate-trial\|source\|zayron\|galaxyzayron\|GALAXY\|site_name\|website" --include=*.js "$D" 2>/dev/null | grep -v node_modules | grep -v "/\.bak" | head -8; }
done
echo DONE
