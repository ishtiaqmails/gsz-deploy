#!/usr/bin/env bash
# Load SEO content + curated FAQs for a batch, then re-embed the semantic brain.
# Usage: bash stepLoadContent.sh pilot.json   (file lives in libsrc/content/)
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
F="${1:-pilot.json}"
echo "--- loading content: $F ---"
node "$SRC/load_content.js" "$SRC/content/$F"
echo
echo "--- bot re-test on the previously-weak queries ---"
for q in "something to watch movies in 4k" "i need to hide my ip and browse safely" "will this run on firestick" "does netflix have 4k"; do
  echo "Q: $q"
  curl -s -X POST http://127.0.0.1:3900/api/support/message -H 'Content-Type: application/json' -d "{\"message\":\"$q\"}" | sed 's/\\n/ | /g' | head -c 300; echo; echo
done
echo "DONE — content loaded + brain reindexed. Product pages + bot now use the richer knowledge."
