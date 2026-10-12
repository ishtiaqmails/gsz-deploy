#!/usr/bin/env bash
# #73 — email verification: make .env authoritative (dotenv override) so the live
# process reads the Brevo key (it was empty in the pm2-injected env). server.js.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-mailfix-$TS"; cd "$GSZ"
F=server.js
mkdir -p "$BK"; cp "$GSZ/$F" "$BK/$F"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$F" "$GSZ/$F"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR
node "$SRC/patch_dotenvoverride.js" "$GSZ"
node --check "$GSZ/$F" && echo "   server.js ok"
trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — .env now authoritative; Brevo key should load. Verify with the email test next."
