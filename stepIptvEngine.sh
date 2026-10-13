#!/usr/bin/env bash
# IPTV Library Engine — server side. Installs the engine libs + route + storage into the live GSZ
# app. Self-aware server list from the catalog; the phone pushes each panel's M3U here and we
# clean + de-dupe + store a tiny compressed snapshot. Backs up, validates, rolls back on any error.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-iptveng-$TS"; cd "$GSZ"
mkdir -p "$BK"
cp "$GSZ/server.js" "$BK/server.js"
restore(){ echo "!! FAILED — restoring server.js"; cp "$BK/server.js" "$GSZ/server.js"; pm2 restart gsz >/dev/null 2>&1 || true; }
trap 'restore' ERR

# 1) engine libraries
mkdir -p "$GSZ/lib/iptv"
for f in fetch.js m3u.js clean.js credsource.js proxy.js pages.js; do
  cp -f "$SRC/iptv/$f" "$GSZ/lib/iptv/$f"; node --check "$GSZ/lib/iptv/$f"
done
# 2) route
cp -f "$SRC/iptv_route.js" "$GSZ/routes/iptv.js"; node --check "$GSZ/routes/iptv.js"
echo "   engine libs + route ok"

# 3) storage + show the self-aware server list
node "$SRC/iptv_migrate.js"

# 4) ingest key (the phone authenticates with this)
if ! grep -q '^IPTV_INGEST_KEY=' "$GSZ/.env" 2>/dev/null; then
  K=$(node -e 'console.log(require("crypto").randomBytes(24).toString("hex"))')
  echo "IPTV_INGEST_KEY=$K" >> "$GSZ/.env"
  echo "   generated IPTV_INGEST_KEY"
fi

# 5) mount the route (idempotent, single layer)
node "$SRC/iptv_mount.js" "$GSZ/server.js"
node --check "$GSZ/server.js"

trap - ERR
pm2 restart gsz --update-env >/dev/null
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }
  sleep 1
done

KEY=$(grep '^IPTV_INGEST_KEY=' "$GSZ/.env" | cut -d= -f2-)
echo
echo "=== IPTV Library Engine (server side) installed ==="
echo "INGEST KEY (needed for the phone setup): $KEY"
echo
echo "--- live server list the engine will refresh ---"
curl -s "http://127.0.0.1:3900/internal/iptv/servers?key=$KEY"
echo
echo "DONE"
