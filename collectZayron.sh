#!/usr/bin/env bash
# Snapshot zayron.tv store-relevant source (/opt/zayron) into gsz-deploy/_zayron for audit.
# Code only — .env and secrets are never copied.
set -Eeuo pipefail
Z=/opt/zayron; DST=/opt/gsz-deploy/_zayron
mkdir -p "$DST"

# directory listings so we learn the real layout
for d in routes lib public views; do
  [ -d "$Z/$d" ] && ls -1 "$Z/$d" > "$DST/_ls_$(echo "$d" | tr '/' '_').txt" 2>/dev/null || true
done

# key plumbing files (bot queue, toggles, panels, db, trial route, trial UI)
for f in server.js package.json lib/botQueue.js lib/trialToggle.js lib/panels.js lib/db.js routes/trial.js public/ztrial.js; do
  [ -f "$Z/$f" ] && cp -f "$Z/$f" "$DST/$(echo "$f" | tr '/' '_')" && echo "copied $f"
done

# all route handlers (store logic lives here)
if [ -d "$Z/routes" ]; then for f in "$Z"/routes/*.js; do [ -f "$f" ] && cp -f "$f" "$DST/routes_$(basename "$f")"; done; echo "copied routes/*.js"; fi

# map what already exists for buying/payment/delivery (vs what's missing)
grep -rni "checkout\|\border\b\|payment\|deliver\|pay_account\|invoice\|\bcart\b\|\bbuy\b\|price" \
  "$Z/routes" "$Z/lib" "$Z/server.js" --include=*.js 2>/dev/null | grep -vi node_modules > "$DST/_grep_store.txt" || true

cd /opt/gsz-deploy && git add -A && git commit -q -m "zayron source snapshot for audit" && git push -q && echo "PUSHED OK"
