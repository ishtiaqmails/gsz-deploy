#!/usr/bin/env bash
# stepB1gFix.sh — permanent: agent gets a player_api fallback (empty get.php) + server ingest-xtream endpoint.
# Server-side only; the phone self-updates the agent on its next sweep. Future-proof for any empty-get.php panel.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
R=routes/iptv.js
cp -f "$R" "$R.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$R.xbak.$TS" "$R"; rm -f .pj.js; exit 1; }
trap restore ERR

echo "==> writing lib/iptv/agent.sh (get.php first, player_api fallback; backslash-free)"
cat > lib/iptv/agent.sh <<'AGENTSH'
#!/data/data/com.termux/files/usr/bin/env sh
# GSZ IPTV agent — self-looping. Pulls only servers that need data (missing/empty/stale).
# get.php M3U first; if empty, falls back to player_api (same content over a residential IP).
BASE="__BASE__"
KEY="__KEY__"
INTERVAL=7200
TMP="$HOME/.gsz-iptv"; mkdir -p "$TMP"
ts(){ date "+%H:%M:%S"; }
termux-wake-lock 2>/dev/null || true

# fetch one player_api action to a file; empty -> "[]" so the combined JSON stays valid
xt(){ curl -s --max-time 900 "$XB&action=$1" -o "$2" 2>/dev/null; [ -s "$2" ] || printf '[]' > "$2"; }

# pull one panel: $1=server $2=sku $3=extra query (&fresh=1). 0=pushed, 1=empty, 2=no link
pull(){
  URLJSON=$(curl -s --max-time 200 "$BASE/internal/iptv/url/$2?key=$KEY$3")
  M3U=$(printf '%s' "$URLJSON" | grep -o '"m3u_url":"[^"]*"' | sed 's/"m3u_url":"//; s/"$//')
  [ -z "$M3U" ] && { echo "$(ts) [$1] no order/trial yet - skipping"; return 2; }
  curl -s --max-time 1800 --compressed -o "$TMP/lib.m3u" "$M3U" 2>/dev/null
  SZ=$(wc -c < "$TMP/lib.m3u" 2>/dev/null || echo 0)
  if [ "${SZ:-0}" -ge 1000 ]; then
    echo "$(ts) [$1] pushing M3U (${SZ}b)..."
    RESP=$(gzip -c "$TMP/lib.m3u" | curl -s --max-time 600 -X POST -H "x-iptv-key: $KEY" -H "Content-Type: application/octet-stream" --data-binary @- "$BASE/internal/iptv/ingest/$1")
    echo "$(ts) [$1] $RESP"; rm -f "$TMP/lib.m3u"; return 0
  fi
  echo "$(ts) [$1] get.php empty (${SZ}b) - trying player_api..."
  HOST=$(printf '%s' "$M3U" | sed 's#/get.php.*##')
  USER=$(printf '%s' "$M3U" | sed 's/.*[?&]username=//; s/&.*//')
  PASS=$(printf '%s' "$M3U" | sed 's/.*[?&]password=//; s/&.*//')
  XB="$HOST/player_api.php?username=$USER&password=$PASS"
  xt get_live_categories "$TMP/lc"; xt get_vod_categories "$TMP/vc"; xt get_series_categories "$TMP/sc"
  xt get_live_streams "$TMP/l"; xt get_vod_streams "$TMP/v"; xt get_series "$TMP/s"
  TOT=$(( $(wc -c < "$TMP/l" 2>/dev/null || echo 0) + $(wc -c < "$TMP/v" 2>/dev/null || echo 0) + $(wc -c < "$TMP/s" 2>/dev/null || echo 0) ))
  if [ "${TOT:-0}" -lt 60 ]; then echo "$(ts) [$1] player_api empty too"; rm -f "$TMP"/lc "$TMP"/vc "$TMP"/sc "$TMP"/l "$TMP"/v "$TMP"/s "$TMP/lib.m3u"; return 1; fi
  echo "$(ts) [$1] pushing via player_api (${TOT}b)..."
  RESP=$({ printf '{"live_categories":'; cat "$TMP/lc"; printf ',"vod_categories":'; cat "$TMP/vc"; printf ',"series_categories":'; cat "$TMP/sc"; printf ',"live":'; cat "$TMP/l"; printf ',"vod":'; cat "$TMP/v"; printf ',"series":'; cat "$TMP/s"; printf '}'; } | gzip -c | curl -s --max-time 900 -X POST -H "x-iptv-key: $KEY" -H "Content-Type: application/octet-stream" --data-binary @- "$BASE/internal/iptv/ingest-xtream/$1")
  echo "$(ts) [$1] $RESP"; rm -f "$TMP"/lc "$TMP"/vc "$TMP"/sc "$TMP"/l "$TMP"/v "$TMP"/s "$TMP/lib.m3u"; return 0
}

echo "$(ts) sweep starting - checking which servers need data"
RAW=$(curl -s --max-time 30 "$BASE/internal/iptv/servers?key=$KEY&stale=1")
printf '%s' "$RAW" | grep -oE '"server":"[^"]*"' | cut -d'"' -f4 > "$TMP/srv"
printf '%s' "$RAW" | grep -oE '"sku":"[^"]*"' | cut -d'"' -f4 > "$TMP/sku"
if [ ! -s "$TMP/srv" ]; then echo "$(ts) all servers fresh - nothing to pull this sweep"
else
  paste -d' ' "$TMP/srv" "$TMP/sku" > "$TMP/list"
  while read SERVER SKU; do
    [ -z "$SERVER" ] && continue
    echo "$(ts) [$SERVER] resolving link..."
    pull "$SERVER" "$SKU" ""; rc=$?
    if [ "$rc" = "1" ]; then echo "$(ts) [$SERVER] retrying with a fresh order/trial..."; pull "$SERVER" "$SKU" "&fresh=1"; fi
    sleep 3
  done < "$TMP/list"
fi
echo "$(ts) sweep done - self-updating + sleeping ${INTERVAL}s"
curl -s --max-time 30 "$BASE/internal/iptv/agent.sh?key=$KEY" -o "$HOME/gsz-iptv.sh" 2>/dev/null
sleep "$INTERVAL"
exec sh "$HOME/gsz-iptv.sh"
AGENTSH

echo "==> patching routes/iptv.js (file-based agent route + ingest-xtream endpoint)"
cat > .pj.js <<'PJS'
var fs = require('fs');
var F = 'routes/iptv.js';
var s = fs.readFileSync(F, 'utf8');

// 1) replace the AGENT array + agent.sh route with a file-reading route
var a = s.indexOf('  const AGENT = [');
var rstart = s.indexOf("router.get('/internal/iptv/agent.sh'", a);
var rend = s.indexOf('});', rstart);
if (a < 0 || rstart < 0 || rend < 0) { console.log('  agent block not found'); process.exit(2); }
rend += 3;
var newRoute = `  router.get('/internal/iptv/agent.sh', auth, (req, res) => {
    const base = (process.env.SITE_BASE_URL || 'https://galaxyzayron.store').replace(/[/]+$/, '');
    let src = ''; try { src = require('fs').readFileSync(require('path').join(__dirname, '..', 'lib', 'iptv', 'agent.sh'), 'utf8'); } catch (e) { src = '# agent unavailable'; }
    res.type('text/plain').send(src.replace(/__BASE__/g, base).replace(/__KEY__/g, KEY) + String.fromCharCode(10));
  });`;
s = s.slice(0, a) + newRoute + s.slice(rend);
console.log('  agent route: file-based');

// 2) insert fromXtream + ingest-xtream endpoint before store()
var anchor = '  async function store(server, name, enh, source, via) {';
if (s.split(anchor).length - 1 !== 1) { console.log('  store anchor x' + (s.split(anchor).length - 1)); process.exit(2); }
var insert = `  function fromXtream(x) {
    const catMap = rows => { const m = {}; (rows || []).forEach(c => { if (c && c.category_id != null) m[String(c.category_id)] = c.category_name || ''; }); return m; };
    const liveCats = catMap(x.live_categories), vodCats = catMap(x.vod_categories), seriesCats = catMap(x.series_categories);
    const map = (arr, cats) => (arr || []).map(r => ({ name: r.name || r.title || '', category_name: cats[String(r.category_id)] || '', stream_icon: r.stream_icon || r.cover || '' }));
    return { ok: true, live: map(x.live, liveCats), vod: map(x.vod, vodCats), series: (x.series || []).map(r => ({ name: r.name || r.title || '', category_name: seriesCats[String(r.category_id)] || '', cover: r.cover || '', episode_count: 0 })) };
  }
  router.post('/internal/iptv/ingest-xtream/:server', auth, express.raw({ type: () => true, limit: '400mb' }), async (req, res) => {
    try {
      let buf = req.body;
      if (!Buffer.isBuffer(buf) || !buf.length) return res.status(400).json({ ok: false, error: 'empty_body' });
      const gz = buf.length > 2 && buf[0] === 0x1f && buf[1] === 0x8b;
      const txt = gz ? zlib.gunzipSync(buf).toString() : buf.toString();
      let x; try { x = JSON.parse(txt); } catch (e) { return res.status(400).json({ ok: false, error: 'bad_json', detail: e.message }); }
      const lib = fromXtream(x);
      if ((lib.live.length + lib.vod.length + lib.series.length) === 0) return res.json({ ok: false, error: 'empty_library', note: 'nothing parsed - keeping previous snapshot' });
      const enh = clean.enhance(lib);
      const nm = (await pool.query('SELECT name FROM products WHERE slug=$1', [req.params.server])).rows[0];
      await store(req.params.server, nm ? nm.name : req.params.server, enh, 'phone', 'xtream');
      res.json({ ok: true, server: req.params.server, counts: enh.counts, raw: enh.rawCounts });
    } catch (e) { res.status(500).json({ ok: false, error: 'ingest_failed', detail: String(e.message || e) }); }
  });

`;
s = s.split(anchor).join(insert + anchor);
console.log('  ingest-xtream endpoint: added');
fs.writeFileSync(F, s);
process.exit(0);
PJS
node .pj.js
node --check "$R"
rm -f .pj.js
echo "   node check ok"
trap - ERR

echo "==> restart site + health + agent serve check"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health failed — rolling back"; cp -f "$R.xbak.$TS" "$R"; pm2 restart "$APP" >/dev/null 2>&1; exit 1; }
KEY=$(grep -E '^IPTV_INGEST_KEY=' .env 2>/dev/null | cut -d= -f2- | tr -d '"')
HAS=$(curl -s "http://127.0.0.1:$PORT/internal/iptv/agent.sh?key=$KEY" | grep -c "ingest-xtream" || true)
echo "   agent now serves player_api fallback: $([ "${HAS:-0}" -ge 1 ] && echo YES || echo NO)"
echo "DONE — B1G-style panels now pull via player_api automatically. Phone self-updates next sweep (or type 'gsz' to trigger now)."
