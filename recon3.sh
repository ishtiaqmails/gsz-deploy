#!/usr/bin/env bash
# recon3 : READ-ONLY. Reveals how /static is actually served (Caddy vs Express),
# the gsz port, whether .webp files already exist on disk, and how banners are
# referenced as .webp. Changes nothing.
cd /opt/gsz

echo "=== gsz listen port ==="
grep -rnE "\.listen\(|process\.env\.PORT|PORT" server.js | head -8
grep -iE "^PORT|PORT=" .env 2>/dev/null | head

echo; echo "=== Caddy: locate config ==="
ls -la /etc/caddy/Caddyfile 2>/dev/null
CF=$(ls /etc/caddy/Caddyfile 2>/dev/null || echo /etc/caddy/Caddyfile)
echo "--- galaxyzayron block ---"
awk '/galaxyzayron\.store/{f=1} f{print} f&&/^}[[:space:]]*$/{exit}' "$CF" 2>/dev/null | head -70

echo; echo "=== does Caddy serve /static from disk anywhere? (file_server/root) ==="
grep -rniE "file_server|root \*|/static|galaxyzayron" /etc/caddy/ 2>/dev/null | head -20

echo; echo "=== webp files already on disk in public/img? ==="
echo "webp count: $(ls public/img/*.webp 2>/dev/null | wc -l)   png count: $(ls public/img/*.png 2>/dev/null | wc -l)"
ls -la public/img/*.webp 2>/dev/null | head -6
echo "-- banner files (png vs webp) --"
ls -la public/img/banner-entertainment-* 2>/dev/null

echo; echo "=== how banners are referenced (.webp?) in templates/libs ==="
grep -rnE "\.webp|banner" views lib --include=*.ejs --include=*.js 2>/dev/null | grep -iE "webp|bannerMap|banner_url|\.banner" | head -15

echo; echo "=== static + imgopt in server.js ==="
grep -n "/static\|imgopt" server.js | head
echo "=== recon3 done ==="
