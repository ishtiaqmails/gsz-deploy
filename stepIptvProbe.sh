#!/usr/bin/env bash
# IPTV Library Engine — real-panel probe. This does NOT touch the live site; it only runs the
# fetch+clean core against ONE panel so we see the true library size and design storage to fit.
# Your credentials stay on this server (passed as arguments), never committed, never sent anywhere.
set -euo pipefail
cd "$(dirname "$0")/libsrc/iptv"

for f in fetch.js m3u.js clean.js credsource.js test.js; do
  [ -f "$f" ] || { echo "MISSING $f — run: cd /opt/gsz-deploy && git pull"; exit 1; }
done
node -e "require('./fetch');require('./m3u');require('./clean');require('./credsource');console.log('engine files OK')"

echo
echo "FULLY AUTOMATIC (recommended) — the engine sources a read-only login itself via gsz-api"
echo "(orders-first, free-trial fallback); you type NO credentials and no credit is spent:"
echo
echo "    node libsrc/iptv/test.js  --auto  SKU-00030        # Opplex TV (any IPTV product's SKU)"
echo
echo "Manual sources also work if you want to point it at a specific line (creds stay on this box):"
echo "    node libsrc/iptv/test.js  'http://PANEL-HOST:PORT'  'USERNAME'  'PASSWORD'"
echo "    node libsrc/iptv/test.js  --m3u  'http://PANEL-HOST/get.php?username=U&password=P&type=m3u_plus'"
echo
echo "(run from /opt/gsz-deploy). It prints raw-vs-clean counts, categories, samples,"
echo "and the gzipped snapshot size — that tells us exactly how to store it."
