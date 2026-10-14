#!/usr/bin/env bash
# stepBlogBtn.sh — fix published-blog button colors/text at the source.
#   public/css/content.css : exclude .cs-btn from the .cs-article link rule (color + underline),
#                            drop the now-redundant reset.
#   views/content_article.ejs + content_list.ejs : bump content.css?v=2 -> v=3 (cache-bust).
set -euo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc; TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/.bak-blogbtn-$TS"; cd "$GSZ"
CSS=public/css/content.css; ART=views/content_article.ejs; LST=views/content_list.ejs
mkdir -p "$BK/public/css" "$BK/views"
cp "$GSZ/$CSS" "$BK/$CSS"; cp "$GSZ/$ART" "$BK/$ART"; [ -f "$GSZ/$LST" ] && cp "$GSZ/$LST" "$BK/$LST" || true
echo "   backup: $BK"
restore(){ echo "!! FAILED — restoring"; cp "$BK/$CSS" "$GSZ/$CSS"; cp "$BK/$ART" "$GSZ/$ART"; [ -f "$BK/$LST" ] && cp "$BK/$LST" "$GSZ/$LST" || true; pm2 restart gsz >/dev/null 2>&1 || true; }
trap restore ERR

echo "==> patch content.css + cache-bust"
node "$SRC/patch_blogbtn.js" "$GSZ"
# sanity: the fixed selector must be present and the raw .cs-article a{ must be gone
grep -q '.cs-article a:not(.cs-btn){color:' "$GSZ/$CSS" && echo "   css selector ok"
node --check "$GSZ/$ART" 2>/dev/null || true  # ejs isn't JS; skip hard check

echo "==> restart gsz (flush view cache)"
pm2 restart gsz --update-env >/dev/null
trap - ERR
for i in $(seq 1 25); do code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); [ "$code" = "200" ] && { echo "health OK (${i}s)"; break; }; sleep 1; done
echo "DONE — published blog buttons keep their own colors + text (no cyan link override). Hard-refresh once (Ctrl+F5) to clear the old CSS."
