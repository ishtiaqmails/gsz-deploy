#!/usr/bin/env bash
set -euo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BK="$GSZ/lib/botsync.js.bak-step158-$TS"
echo "==> step158: sync bot's new fields (retrieve/warranty_days/delivery_note/stock) (#7 Phase 1)"
cp "$GSZ/lib/botsync.js" "$BK"; echo "    backup: $BK"

restore(){ echo "!! error — restoring"; cp "$BK" "$GSZ/lib/botsync.js" 2>/dev/null || true; }
trap 'restore' ERR

echo "==> migration: bot_products new columns"
NODE_PATH="$GSZ/node_modules" node -e "
require('dotenv').config({path:'$GSZ/.env'});
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{ try{
  await p.query('ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS retrieve jsonb');
  await p.query('ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS warranty_days integer');
  await p.query('ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS delivery_note text');
  await p.query('ALTER TABLE bot_products ADD COLUMN IF NOT EXISTS stock jsonb');
  console.log('    columns ready'); await p.end();
}catch(e){ console.error('    migration failed: '+e.message); process.exit(1); } })();
"

PATCHER=$(mktemp /tmp/patch_step158.XXXXXX.js)
echo "J3VzZSBzdHJpY3QnOwovKiBzdGVwMTU4IOKAlCAjNyBQaGFzZSAxOiBzeW5jIHRoZSBib3QncyBuZXcgcGVyLXByb2R1Y3QgZmllbGRzIGludG8gYm90X3Byb2R1Y3RzOgogICByZXRyaWV2ZSAob3RwL2xpbmsgY2FwYWJpbGl0eSksIHdhcnJhbnR5X2RheXMsIGRlbGl2ZXJ5X25vdGUsIHN0b2NrLiBCYWNrd2FyZC0KICAgY29tcGF0aWJsZSAoYWxsIG9wdGlvbmFsKS4gUGFpcnMgd2l0aCBhIHNtYWxsIGNvbHVtbiBtaWdyYXRpb24uIElkZW1wb3RlbnQuICovCmNvbnN0IGZzID0gcmVxdWlyZSgnZnMnKTsgY29uc3QgcGF0aCA9IHJlcXVpcmUoJ3BhdGgnKTsKY29uc3QgUk9PVCA9IHByb2Nlc3MuYXJndlsyXTsgaWYgKCFST09UKSB7IGNvbnNvbGUuZXJyb3IoJ3VzYWdlOiBub2RlIHBhdGNoX3N0ZXAxNTguanMgPGdzei1yb290PicpOyBwcm9jZXNzLmV4aXQoMSk7IH0KZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsgbGV0IHMgPSBmcy5yZWFkRmlsZVN5bmMoZmlsZSwgJ3V0ZjgnKTsKICBmb3IgKGNvbnN0IGUgb2YgZWRpdHMpIHsKICAgIGlmIChzLmluZGV4T2YoZS5ndWFyZCkgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOyBjb250aW51ZTsgfQogICAgY29uc3QgZmlyc3QgPSBzLmluZGV4T2YoZS5maW5kKTsKICAgIGlmIChmaXJzdCA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgaWYgKHMuaW5kZXhPZihlLmZpbmQsIGZpcnN0ICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBzID0gcy5zbGljZSgwLCBmaXJzdCkgKyBlLnJlcGxhY2UgKyBzLnNsaWNlKGZpcnN0ICsgZS5maW5kLmxlbmd0aCk7CiAgICBjb25zb2xlLmxvZygncGF0Y2hlZDogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgfQogIGZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7Cn0KCnBhdGNoKCdsaWIvYm90c3luYy5qcycsIFsKICB7IG5hbWU6ICdpbnNlcnQtY29scycsCiAgICBndWFyZDogJ3R5cGVzLHJldHJpZXZlLHdhcnJhbnR5X2RheXMsZGVsaXZlcnlfbm90ZSxzdG9jayxtaXNzaW5nJywKICAgIGZpbmQ6ICd0eXBlcyxtaXNzaW5nLHVwZGF0ZWRfYXQpJywKICAgIHJlcGxhY2U6ICd0eXBlcyxyZXRyaWV2ZSx3YXJyYW50eV9kYXlzLGRlbGl2ZXJ5X25vdGUsc3RvY2ssbWlzc2luZyx1cGRhdGVkX2F0KScgfSwKCiAgeyBuYW1lOiAnaW5zZXJ0LXZhbHVlcycsCiAgICBndWFyZDogJyQ5LCQxMCwkMTEsJDEyLCQxMywkMTQsZmFsc2Usbm93KCkpJywKICAgIGZpbmQ6ICckOSwkMTAsZmFsc2Usbm93KCkpJywKICAgIHJlcGxhY2U6ICckOSwkMTAsJDExLCQxMiwkMTMsJDE0LGZhbHNlLG5vdygpKScgfSwKCiAgeyBuYW1lOiAnY29uZmxpY3Qtc2V0JywKICAgIGd1YXJkOiAncmV0cmlldmU9RVhDTFVERUQucmV0cmlldmUnLAogICAgZmluZDogJ3R5cGVzPUVYQ0xVREVELnR5cGVzLCBtaXNzaW5nPWZhbHNlLCB1cGRhdGVkX2F0PW5vdygpJywKICAgIHJlcGxhY2U6ICd0eXBlcz1FWENMVURFRC50eXBlcywgcmV0cmlldmU9RVhDTFVERUQucmV0cmlldmUsIHdhcnJhbnR5X2RheXM9RVhDTFVERUQud2FycmFudHlfZGF5cywgZGVsaXZlcnlfbm90ZT1FWENMVURFRC5kZWxpdmVyeV9ub3RlLCBzdG9jaz1FWENMVURFRC5zdG9jaywgbWlzc2luZz1mYWxzZSwgdXBkYXRlZF9hdD1ub3coKScgfSwKCiAgeyBuYW1lOiAncGFyYW1zJywKICAgIGd1YXJkOiAncC5yZXRyaWV2ZSAhPSBudWxsID8gSlNPTi5zdHJpbmdpZnkocC5yZXRyaWV2ZSknLAogICAgZmluZDogJ0pTT04uc3RyaW5naWZ5KHAudHlwZXMgfHwgW10pJywKICAgIHJlcGxhY2U6CiAgICAgICdKU09OLnN0cmluZ2lmeShwLnR5cGVzIHx8IFtdKSxcbicgKwogICAgICAnICAgICAgICAocC5yZXRyaWV2ZSAhPSBudWxsID8gSlNPTi5zdHJpbmdpZnkocC5yZXRyaWV2ZSkgOiBudWxsKSxcbicgKwogICAgICAnICAgICAgICAocC53YXJyYW50eV9kYXlzICE9IG51bGwgPyBwYXJzZUludChwLndhcnJhbnR5X2RheXMsIDEwKSA6IG51bGwpLFxuJyArCiAgICAgICcgICAgICAgIChwLmRlbGl2ZXJ5X25vdGUgIT0gbnVsbCA/IFN0cmluZyhwLmRlbGl2ZXJ5X25vdGUpIDogbnVsbCksXG4nICsKICAgICAgJyAgICAgICAgKHAuc3RvY2sgIT0gbnVsbCA/IEpTT04uc3RyaW5naWZ5KHAuc3RvY2spIDogbnVsbCknIH0KXSk7Cgpjb25zb2xlLmxvZygnQUxMIFBBVENIRVMgQVBQTElFRCcpOwo=" | base64 -d > "$PATCHER"
echo "==> applying"
NODE_PATH="$GSZ/node_modules" node "$PATCHER" "$GSZ"
echo "==> validating"
node --check "$GSZ/lib/botsync.js" && echo "    node --check ok"

echo "==> restarting"
pm2 restart gsz >/dev/null 2>&1 || pm2 restart gsz
CODE=000
for i in $(seq 1 25); do sleep 1; CODE=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || echo 000); [ "$CODE" = "200" ] && break; done
[ "$CODE" = "200" ] || { echo "    homepage $CODE after ${i}s"; false; }
echo "    homepage 200: OK (after ${i}s)"

echo "==> re-syncing catalog from bot (pull new fields now)"
SEC=$(grep -E '^GSZ_BOT_API_KEY=' "$GSZ/.env" >/dev/null 2>&1 && echo configured || echo '')
NODE_PATH="$GSZ/node_modules" node -e "
require('dotenv').config({path:'$GSZ/.env'});
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
const { syncProducts } = require('$GSZ/lib/botsync');
(async()=>{ try{ const n=await syncProducts(p); console.log('    synced '+n+' products'); const r=await p.query(\"SELECT count(*) FILTER (WHERE retrieve IS NOT NULL)::int rc, count(*) FILTER (WHERE delivery_note IS NOT NULL)::int dc, count(*) FILTER (WHERE stock IS NOT NULL)::int sc FROM bot_products\"); console.log('    with retrieve: '+r.rows[0].rc+' · with note: '+r.rows[0].dc+' · with stock: '+r.rows[0].sc); await p.end(); }catch(e){ console.error('    sync note: '+e.message+' (fields still stored on next successful sync)'); process.exit(0); } })();
"

rm -f "$PATCHER"
trap - ERR
echo ""
echo "==> step158 OK  The catalog sync now stores the bot's retrieve (otp/link), warranty_days, delivery_note and live stock per product. Next step wires these onto the order page + storefront."
