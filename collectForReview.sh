#!/usr/bin/env bash
# Snapshot the live paid/renew source files into the repo so they can be code-reviewed
# in the workspace (no large console output). Secrets stay in .env and are never copied.
set -Eeuo pipefail
GSZ=/opt/gsz; DST=/opt/gsz-deploy/_review
mkdir -p "$DST"
for f in routes/checkout.js lib/botapi.js lib/wanotify.js routes/whatsapp.js; do
  if [ -f "$GSZ/$f" ]; then cp -f "$GSZ/$f" "$DST/$(echo "$f" | tr '/' '_')"; echo "copied $f"; fi
done
cd /opt/gsz-deploy && git add -A && git commit -q -m "review snapshot: paid/renew source" && git push -q && echo "pushed for review"
