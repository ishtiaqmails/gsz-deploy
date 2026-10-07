#!/usr/bin/env bash
# ============================================================================
#  GSZ step117 — fast product images. Installs sharp, optimizes all existing
#  images in place (resize ~900px + strong compression; originals preserved in
#  public/img/.img-orig), and resizes every future upload. Safe + idempotent;
#  restores code AND images on any failure.
# ============================================================================
set -euo pipefail
GSZ=/opt/gsz; IMG="$GSZ/public/img"
TS=$(date +%Y%m%d-%H%M%S); BK="$GSZ/.bak-step117-$TS"; TMP=$(mktemp -d)
F=routes/adminProductImage.js

echo "==> step117: fast product images"
echo "==> ensuring sharp is installed (this can take a minute)"
( cd "$GSZ" && npm install sharp --no-audit --no-fund --silent ) || { echo "!! npm install sharp failed (network/native build). Nothing changed."; exit 1; }
node -e "require('$GSZ/node_modules/sharp')" || { echo "!! sharp not loadable after install. Nothing changed."; exit 1; }

mkdir -p "$BK/$(dirname "$F")"; cp "$GSZ/$F" "$BK/$F"
echo "    backup: $BK"
restore() {
  echo "!!  FAILED — restoring"
  cp "$BK/$F" "$GSZ/$F"
  if [ -d "$IMG/.img-orig" ]; then cp -a "$IMG/.img-orig/." "$IMG/" 2>/dev/null || true; fi
  pm2 restart gsz >/dev/null 2>&1 || true
  echo "!!  restored."
}
trap 'restore' ERR

echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTE3IHBhdGNoZXIg4oCUIHJlc2l6ZSBldmVyeSBmdXR1cmUgcHJvZHVjdC1pbWFnZSB1cGxvYWQgKHNoYXJwKS4KICAgSWRlbXBvdGVudDsgYWJvcnRzIG9uIG1pc3Npbmcvbm9uLXVuaXF1ZSBhbmNob3IuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKSwgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsKaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBwYXRjaF9zdGVwMTE3LmpzIDxnc3otcm9vdD4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmZ1bmN0aW9uIHBhdGNoKHJlbCwgZWRpdHMpIHsKICBjb25zdCBmaWxlID0gcGF0aC5qb2luKFJPT1QsIHJlbCk7IGxldCBzID0gZnMucmVhZEZpbGVTeW5jKGZpbGUsICd1dGY4Jyk7CiAgZm9yIChjb25zdCBlIG9mIGVkaXRzKSB7CiAgICBpZiAocy5pbmRleE9mKGUuZ3VhcmQpID49IDApIHsgY29uc29sZS5sb2coJ3NraXAgKGFscmVhZHkpOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsgY29udGludWU7IH0KICAgIGNvbnN0IGZpcnN0ID0gcy5pbmRleE9mKGUuZmluZCk7CiAgICBpZiAoZmlyc3QgPCAwKSB0aHJvdyBuZXcgRXJyb3IoJ0FOQ0hPUiBNSVNTOiAnICsgcmVsICsgJyA6OiAnICsgZS5uYW1lKTsKICAgIGlmIChzLmluZGV4T2YoZS5maW5kLCBmaXJzdCArIDEpID49IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE5PVCBVTklRVUU6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgcyA9IHMuc2xpY2UoMCwgZmlyc3QpICsgZS5yZXBsYWNlICsgcy5zbGljZShmaXJzdCArIGUuZmluZC5sZW5ndGgpOwogICAgY29uc29sZS5sb2coJ3BhdGNoZWQ6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogIH0KICBmcy53cml0ZUZpbGVTeW5jKGZpbGUsIHMpOwp9CmNvbnN0IFJFUV9GSU5EID0gImNvbnN0IG11bHRlciA9IHJlcXVpcmUoJ211bHRlcicpOyI7CmNvbnN0IFJFUV9SRVBMID0gImNvbnN0IG11bHRlciA9IHJlcXVpcmUoJ211bHRlcicpO1xubGV0IHNoYXJwID0gbnVsbDsgdHJ5IHsgc2hhcnAgPSByZXF1aXJlKCdzaGFycCcpOyB9IGNhdGNoIChlKSB7IC8qIG9wdGlvbmFsOyB1cGxvYWRzIHN0aWxsIHdvcmsgdW5yZXNpemVkICovIH0iOwpjb25zdCBVUF9GSU5EID0KICAiICAgICAgaWYgKCFyZXEuZmlsZSkgcmV0dXJuIHJlcy5yZWRpcmVjdCgnL2FkbWluL3Byb2R1Y3RzLycgKyByZXEucGFyYW1zLmlkICsgJy9lZGl0P29rPUNob29zZSthbitpbWFnZStmaWxlJyk7XG4iCisgIiAgICAgIGF3YWl0IHBvb2wucXVlcnkoJ1VQREFURSBwcm9kdWN0cyBTRVQgaW1hZ2U9JDEgV0hFUkUgaWQ9JDInLCBbcmVxLmZpbGUuZmlsZW5hbWUsIHJlcS5wYXJhbXMuaWRdKTsiOwpjb25zdCBVUF9SRVBMID0KICAiICAgICAgaWYgKCFyZXEuZmlsZSkgcmV0dXJuIHJlcy5yZWRpcmVjdCgnL2FkbWluL3Byb2R1Y3RzLycgKyByZXEucGFyYW1zLmlkICsgJy9lZGl0P29rPUNob29zZSthbitpbWFnZStmaWxlJyk7XG4iCisgIiAgICAgIGlmIChzaGFycCkgeyB0cnkge1xuIgorICIgICAgICAgIGNvbnN0IGZwID0gcmVxLmZpbGUucGF0aCwgZXh0ID0gKHBhdGguZXh0bmFtZShmcCkgfHwgJycpLnRvTG93ZXJDYXNlKCk7XG4iCisgIiAgICAgICAgY29uc3QgbWV0YSA9IGF3YWl0IHNoYXJwKGZwKS5tZXRhZGF0YSgpO1xuIgorICIgICAgICAgIGxldCBwaXBlID0gc2hhcnAoZnApLnJvdGF0ZSgpOyBpZiAobWV0YS53aWR0aCAmJiBtZXRhLndpZHRoID4gOTAwKSBwaXBlID0gcGlwZS5yZXNpemUoeyB3aWR0aDogOTAwLCB3aXRob3V0RW5sYXJnZW1lbnQ6IHRydWUgfSk7XG4iCisgIiAgICAgICAgbGV0IGJ1ZiA9IG51bGw7XG4iCisgIiAgICAgICAgaWYgKGV4dCA9PT0gJy5qcGcnIHx8IGV4dCA9PT0gJy5qcGVnJykgYnVmID0gYXdhaXQgcGlwZS5qcGVnKHsgcXVhbGl0eTogODIsIG1vempwZWc6IHRydWUgfSkudG9CdWZmZXIoKTtcbiIKKyAiICAgICAgICBlbHNlIGlmIChleHQgPT09ICcud2VicCcpIGJ1ZiA9IGF3YWl0IHBpcGUud2VicCh7IHF1YWxpdHk6IDgyIH0pLnRvQnVmZmVyKCk7XG4iCisgIiAgICAgICAgZWxzZSBpZiAoZXh0ID09PSAnLnBuZycpIGJ1ZiA9IGF3YWl0IHBpcGUucG5nKHsgY29tcHJlc3Npb25MZXZlbDogOSwgcGFsZXR0ZTogdHJ1ZSwgcXVhbGl0eTogODIsIGVmZm9ydDogOCB9KS50b0J1ZmZlcigpO1xuIgorICIgICAgICAgIGlmIChidWYgJiYgYnVmLmxlbmd0aCA+IDApIGZzLndyaXRlRmlsZVN5bmMoZnAsIGJ1Zik7XG4iCisgIiAgICAgIH0gY2F0Y2ggKGUpIHsgLyoga2VlcCBvcmlnaW5hbCBvbiBhbnkgZXJyb3IgKi8gfSB9XG4iCisgIiAgICAgIGF3YWl0IHBvb2wucXVlcnkoJ1VQREFURSBwcm9kdWN0cyBTRVQgaW1hZ2U9JDEgV0hFUkUgaWQ9JDInLCBbcmVxLmZpbGUuZmlsZW5hbWUsIHJlcS5wYXJhbXMuaWRdKTsiOwpwYXRjaCgncm91dGVzL2FkbWluUHJvZHVjdEltYWdlLmpzJywgWwogIHsgbmFtZTogJ3JlcXVpcmUtc2hhcnAnLCBndWFyZDogInNoYXJwID0gcmVxdWlyZSgnc2hhcnAnKSIsIGZpbmQ6IFJFUV9GSU5ELCByZXBsYWNlOiBSRVFfUkVQTCB9LAogIHsgbmFtZTogJ3Jlc2l6ZS1vbi11cGxvYWQnLCBndWFyZDogJ2lmIChzaGFycCkgeyB0cnkgeycsIGZpbmQ6IFVQX0ZJTkQsIHJlcGxhY2U6IFVQX1JFUEwgfQpdKTsKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK" | base64 -d > "$TMP/patch.js"
echo "J3VzZSBzdHJpY3QnOwovKiBPbmUtdGltZSAoaWRlbXBvdGVudCkgaW1hZ2Ugb3B0aW1pemVyLiBPcmlnaW5hbHMgYXJlIHByZXNlcnZlZCBpbiAuaW1nLW9yaWcKICAgb24gZmlyc3QgdG91Y2ggYW5kIGV2ZXJ5IHJ1biByZS1vcHRpbWl6ZXMgRlJPTSB0aGUgb3JpZ2luYWwsIHNvIHJlLXJ1bm5pbmcKICAgbmV2ZXIgZG91YmxlLWNvbXByZXNzZXMuIExpdmUgZmlsZSByZXBsYWNlZCBvbmx5IGlmIHRoZSByZXN1bHQgaXMgc21hbGxlci4gKi8KY29uc3QgZnMgPSByZXF1aXJlKCdmcycpLCBwYXRoID0gcmVxdWlyZSgncGF0aCcpOwpjb25zdCBzaGFycCA9IHJlcXVpcmUoJ3NoYXJwJyk7CmNvbnN0IElNRyA9IHByb2Nlc3MuYXJndlsyXTsKaWYgKCFJTUcpIHsgY29uc29sZS5lcnJvcigndXNhZ2U6IG9wdGltaXplX3N0ZXAxMTcuanMgPGltZ2Rpcj4nKTsgcHJvY2Vzcy5leGl0KDEpOyB9CmNvbnN0IEJBSyA9IHBhdGguam9pbihJTUcsICcuaW1nLW9yaWcnKTsKKGFzeW5jICgpID0+IHsKICBmcy5ta2RpclN5bmMoQkFLLCB7IHJlY3Vyc2l2ZTogdHJ1ZSB9KTsKICBjb25zdCBmaWxlcyA9IGZzLnJlYWRkaXJTeW5jKElNRykuZmlsdGVyKGYgPT4gL15wcm9kXy4qXC4ocG5nfGpwZT9nfHdlYnApJC9pLnRlc3QoZikpOwogIGxldCBiZWZvcmUgPSAwLCBhZnRlciA9IDAsIGRvbmUgPSAwLCBza2lwID0gMDsKICBmb3IgKGNvbnN0IGYgb2YgZmlsZXMpIHsKICAgIGNvbnN0IHNyYyA9IHBhdGguam9pbihJTUcsIGYpOyBsZXQgc3Q7IHRyeSB7IHN0ID0gZnMuc3RhdFN5bmMoc3JjKTsgfSBjYXRjaCAoZSkgeyBjb250aW51ZTsgfSBpZiAoIXN0LmlzRmlsZSgpKSBjb250aW51ZTsKICAgIGNvbnN0IGJha2YgPSBwYXRoLmpvaW4oQkFLLCBmKTsKICAgIHRyeSB7CiAgICAgIGlmICghZnMuZXhpc3RzU3luYyhiYWtmKSkgZnMuY29weUZpbGVTeW5jKHNyYywgYmFrZik7CiAgICAgIGNvbnN0IG9iID0gZnMuc3RhdFN5bmMoYmFrZikuc2l6ZTsgYmVmb3JlICs9IG9iOwogICAgICBjb25zdCBleHQgPSAocGF0aC5leHRuYW1lKGYpIHx8ICcnKS50b0xvd2VyQ2FzZSgpOwogICAgICBjb25zdCBtZXRhID0gYXdhaXQgc2hhcnAoYmFrZikubWV0YWRhdGEoKTsKICAgICAgbGV0IHBpcGUgPSBzaGFycChiYWtmKS5yb3RhdGUoKTsgaWYgKG1ldGEud2lkdGggJiYgbWV0YS53aWR0aCA+IDkwMCkgcGlwZSA9IHBpcGUucmVzaXplKHsgd2lkdGg6IDkwMCwgd2l0aG91dEVubGFyZ2VtZW50OiB0cnVlIH0pOwogICAgICBsZXQgYnVmOwogICAgICBpZiAoZXh0ID09PSAnLmpwZycgfHwgZXh0ID09PSAnLmpwZWcnKSBidWYgPSBhd2FpdCBwaXBlLmpwZWcoeyBxdWFsaXR5OiA4MCwgbW96anBlZzogdHJ1ZSB9KS50b0J1ZmZlcigpOwogICAgICBlbHNlIGlmIChleHQgPT09ICcud2VicCcpIGJ1ZiA9IGF3YWl0IHBpcGUud2VicCh7IHF1YWxpdHk6IDgwIH0pLnRvQnVmZmVyKCk7CiAgICAgIGVsc2UgYnVmID0gYXdhaXQgcGlwZS5wbmcoeyBjb21wcmVzc2lvbkxldmVsOiA5LCBwYWxldHRlOiB0cnVlLCBxdWFsaXR5OiA4MCwgZWZmb3J0OiA4IH0pLnRvQnVmZmVyKCk7CiAgICAgIGF3YWl0IHNoYXJwKGJ1ZikubWV0YWRhdGEoKTsKICAgICAgaWYgKGJ1Zi5sZW5ndGggPiAwICYmIGJ1Zi5sZW5ndGggPCBvYikgeyBmcy53cml0ZUZpbGVTeW5jKHNyYywgYnVmKTsgYWZ0ZXIgKz0gYnVmLmxlbmd0aDsgZG9uZSsrOyB9CiAgICAgIGVsc2UgeyBhZnRlciArPSBvYjsgc2tpcCsrOyB9CiAgICB9IGNhdGNoIChlKSB7IGFmdGVyICs9IHN0LnNpemU7IHNraXArKzsgfQogIH0KICBjb25zb2xlLmxvZygnICAgIGltYWdlcyBvcHRpbWl6ZWQ6ICcgKyBkb25lICsgJywgdW5jaGFuZ2VkOiAnICsgc2tpcCArICcgICgnICsgKGJlZm9yZSAvIDEwNDg1NzYpLnRvRml4ZWQoMSkgKyAnTUIgLT4gJyArIChhZnRlciAvIDEwNDg1NzYpLnRvRml4ZWQoMSkgKyAnTUIpJyk7Cn0pKCkuY2F0Y2goZSA9PiB7IGNvbnNvbGUuZXJyb3IoJ09QVElNSVpFIEZBSUw6ICcgKyBlLm1lc3NhZ2UpOyBwcm9jZXNzLmV4aXQoMSk7IH0pOwo="   | base64 -d > "$TMP/optimize.js"

echo "==> patching upload route"
node "$TMP/patch.js" "$GSZ"
node --check "$GSZ/$F"

BEFORE=$(du -sh "$IMG" 2>/dev/null | cut -f1)
echo "==> optimizing existing images (dir was $BEFORE)"
node "$TMP/optimize.js" "$IMG"
AFTER=$(du -sh "$IMG" 2>/dev/null | cut -f1)

echo "==> restarting app"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
sleep 2

echo "==> health checks"
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
[ "$CODE" = "200" ] && echo "    homepage 200: OK" || { echo "    homepage $CODE"; false; }
IMGF=$(cd "$GSZ" && NODE_PATH="$GSZ/node_modules" node -e "require('dotenv/config');const{Pool}=require('pg');const p=new Pool({host:process.env.DB_HOST,port:+(process.env.DB_PORT||5432),user:process.env.DB_USER,password:process.env.DB_PASS,database:process.env.DB_NAME});p.query(\"SELECT image FROM products WHERE image IS NOT NULL ORDER BY id LIMIT 1\").then(function(r){console.log(r.rows[0]?r.rows[0].image:'');return p.end();}).catch(function(){console.log('')})" 2>/dev/null || true)
if [ -n "$IMGF" ]; then
  CL=$(curl -s -o /dev/null -w '%{size_download}' "http://127.0.0.1:3900/static/img/$IMGF" || echo 0)
  echo "    sample image $IMGF now $(( CL / 1024 )) KB"
fi

trap - ERR; rm -rf "$TMP"
echo ""
echo "==> step117 OK ✅  images $BEFORE -> $AFTER"
echo "    • All existing product images optimized in place (originals kept in public/img/.img-orig)."
echo "    • Every future upload is auto-resized to ~900px + compressed."
echo "    • No filename or database changes — nothing else to update."
