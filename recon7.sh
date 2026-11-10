#!/usr/bin/env bash
# recon7 : READ-ONLY. Shows the footer's social-icons + channel block so it can be
# removed cleanly, and how the waChannel/socials locals are derived. Changes nothing.
cd /opt/gsz

echo "=== store_bottom.ejs lines 20-55 (footer social + channel area) ==="
sed -n '20,55p' views/partials/store_bottom.ejs

echo; echo "=== how waChannel / socials locals are built ==="
grep -rn "waChannel\|socials\b\|social_links\|wa_channel_url" lib/storefront.js routes/*.js | grep -vi '\.bak' | head -15
echo "=== recon7 done ==="
