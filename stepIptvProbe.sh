#!/usr/bin/env bash
# IPTV Library Engine — real-panel probe. This does NOT touch the live site; it only runs the
# fetch+clean core against ONE panel so we see the true library size and design storage to fit.
# Your credentials stay on this server (passed as arguments), never committed, never sent anywhere.
set -euo pipefail
cd "$(dirname "$0")/libsrc/iptv"

for f in fetch.js m3u.js clean.js test.js; do
  [ -f "$f" ] || { echo "MISSING $f — run: cd /opt/gsz-deploy && git pull"; exit 1; }
done
node -e "require('./fetch');require('./m3u');require('./clean');console.log('engine files OK')"

echo
echo "Run the probe with ONE of these (your creds stay on this box):"
echo
echo "  Xtream login:"
echo "    node libsrc/iptv/test.js  'http://PANEL-HOST:PORT'  'USERNAME'  'PASSWORD'"
echo
echo "  M3U playlist:"
echo "    node libsrc/iptv/test.js  --m3u  'http://PANEL-HOST/get.php?username=U&password=P&type=m3u_plus'"
echo
echo "(from /opt/gsz-deploy). It prints raw-vs-clean counts, categories, samples,"
echo "and the gzipped snapshot size — that tells us exactly how to store it."
