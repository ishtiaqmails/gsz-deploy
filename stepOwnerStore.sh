#!/usr/bin/env bash
# stepOwnerStore.sh — owner bot: add find / plans / sell (sell = pull 1 unit + mark SOLD on site). Additive to ownerCommand.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=routes/whatsapp.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .ins_cmd.txt .ins_help.txt .gszm_bot.js; exit 1; }
trap restore ERR
nchk(){ local i; for i in 1 2 3 4 5; do node --check "$F" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing; owner region:"; grep -nE "find\\|search\\|plans\\|sell\\|price_pkr\\|Command error" "$F" | cat -A | head; return 1; }

echo "==> writing insert blocks (raw files — no escape interpretation)"
cat > .ins_cmd.txt <<'INS'
      if (/^(find|search|products|list)\b/i.test(t)) {
        const q = t.replace(/^(find|search|products|list)\s*/i, '').trim(); const args = q ? ['%' + q + '%'] : [];
        const rows = (await pool.query("SELECT p.id, p.name, (SELECT count(*) FROM product_plans pl WHERE pl.product_id=p.id)::int AS plans, (SELECT min(price_pkr) FROM product_plans pl WHERE pl.product_id=p.id) AS minpk, (SELECT min(price_usd) FROM product_plans pl WHERE pl.product_id=p.id AND price_usd>0) AS minusd FROM products p" + (q ? " WHERE p.name ILIKE $1 OR p.slug ILIKE $1" : "") + " ORDER BY p.name LIMIT 60", args)).rows;
        if (!rows.length) return 'No products' + (q ? (' matching "' + q + '"') : '') + '.';
        const lines = rows.map(function (r) { var pp = (r.minpk != null) ? ('Rs ' + Math.round(r.minpk)) : ''; if (r.minusd) pp += (pp ? ' / ' : '') + '$' + Number(r.minusd).toFixed(2); return '• [' + r.id + '] ' + r.name + (pp ? (' — from ' + pp) : '') + ' · ' + r.plans + ' plan(s)'; });
        return ['🛍️ Products' + (q ? (' — "' + q + '"') : ''), ''].concat(lines).concat(['', 'Plans + prices:  plans <id or name>']).join('\n');
      }
      if (/^(plans|product|view)\b/i.test(t)) {
        const q = t.replace(/^(plans|product|view)\s*/i, '').trim(); if (!q) return 'Usage: plans <product id or name>';
        const byId = /^\d+$/.test(q);
        const prow = (await pool.query(byId ? "SELECT id,name FROM products WHERE id=$1 LIMIT 1" : "SELECT id,name FROM products WHERE name ILIKE $1 OR slug ILIKE $1 ORDER BY name LIMIT 1", [byId ? parseInt(q, 10) : ('%' + q + '%')])).rows[0];
        if (!prow) return 'No product found for "' + q + '".';
        const pls = (await pool.query("SELECT pl.id, pl.label, pl.price_pkr, pl.price_usd, pl.source, (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail FROM product_plans pl WHERE pl.product_id=$1 ORDER BY pl.sort, pl.id", [prow.id])).rows;
        if (!pls.length) return prow.name + ' has no plans.';
        const lines = pls.map(function (p) { var price = 'Rs ' + Math.round(p.price_pkr || 0); if (p.price_usd) price += ' / $' + Number(p.price_usd).toFixed(2); var tag = (p.source === 'inventory') ? (' · ' + p.avail + ' in stock') : (p.source === 'portal' ? ' · portal' : (p.source === 'bot' ? ' · bot' : (p.source ? (' · ' + p.source) : ''))); return '• [' + p.id + '] ' + p.label + ' — ' + price + tag; });
        return ['🧩 ' + prow.name, ''].concat(lines).concat(['', 'Sell 1 unit (own-stock):  sell <planId>']).join('\n');
      }
      if (/^(sell|take)\b/i.test(t)) {
        const planId = parseInt(t.replace(/^(sell|take)\s*/i, '').replace(/[^0-9]/g, ''), 10);
        if (!planId) return 'Usage: sell <planId>  (find IDs with:  plans <product>  or  stock)';
        const pl = (await pool.query("SELECT pl.id, pr.name AS pn, pl.label, pl.price_pkr, pl.price_usd FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.id=$1 AND pl.source='inventory'", [planId])).rows[0];
        if (!pl) return 'Plan #' + planId + ' is not an own-stock plan. Send  stock  to see sellable IDs.';
        const ref = 'MANUAL-' + Date.now().toString(36).toUpperCase();
        const got = (await pool.query("UPDATE inventory_items SET status='delivered', order_no=$1, delivered_at=now() WHERE id=(SELECT id FROM inventory_items WHERE plan_id=$2 AND status='available' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED) RETURNING id, payload", [ref, planId])).rows[0];
        if (!got) return '⚠️ Out of stock — no available unit for [' + planId + '] ' + pl.pn + ' — ' + pl.label + '.';
        const left = (await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [planId])).rows[0].n;
        var price = 'Rs ' + Math.round(pl.price_pkr || 0); if (pl.price_usd) price += ' / $' + Number(pl.price_usd).toFixed(2);
        return ['✅ SOLD (marked on website, removed from stock)', '', pl.pn + ' — ' + pl.label, 'Price: ' + price + '  ·  Ref: ' + ref + '  ·  ' + left + ' left', '', got.payload].join('\n');
      }
INS

cat > .ins_help.txt <<'INS'
then one unit per line', '• find [name] — browse all products + prices', '• plans <id|name> — a product’s plans + prices', '• sell <planId> — pull 1 unit + mark it SOLD', ''
INS

echo "==> patching ownerCommand (insert find/plans/sell; extend help)"
cat > .gszm_bot.js <<'JS'
var fs = require('fs');
var f = 'routes/whatsapp.js';
var s = fs.readFileSync(f, 'utf8');
var ins = fs.readFileSync('.ins_cmd.txt', 'utf8').replace(/\n$/, '');
var helpNew = fs.readFileSync('.ins_help.txt', 'utf8').replace(/\n$/, '');
var a = "    } catch (e) { return 'Command error: ' + e.message; }";
var n = s.split(a).length - 1;
if (n !== 1) { console.log('  CMD ANCHOR x' + n + ' — aborting (no change)'); process.exit(2); }
s = s.split(a).join(ins + '\n' + a);
var ha = "then one unit per line', ''";
var hn = s.split(ha).length - 1;
if (hn === 1) { s = s.split(ha).join(helpNew); console.log('  help: updated'); }
else { console.log('  help: anchor x' + hn + ' — skipped (commands still added)'); }
fs.writeFileSync(f, s);
console.log('  commands: inserted (find, plans, sell)');
process.exit(0);
JS
node .gszm_bot.js
nchk
rm -f .ins_cmd.txt .ins_help.txt .gszm_bot.js
echo "   check passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — owner bot: find / plans / sell live. 'sell' marks the unit SOLD on the website so it can't be delivered online."
