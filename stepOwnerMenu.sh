#!/usr/bin/env bash
# stepOwnerMenu.sh — guided owner sell flow: menu -> pick number -> quantity -> deliver + mark SOLD. Session in wa_settings.
set -uo pipefail
GSZ=/opt/gsz; APP=${GSZ_APP:-gsz}
cd "$GSZ" || { echo "no $GSZ"; exit 1; }
PORT=$(grep -E '^PORT=' .env 2>/dev/null | head -1 | cut -d= -f2); PORT=${PORT:-3900}
TS=$(date +%s)
F=routes/whatsapp.js
cp -f "$F" "$F.xbak.$TS"
restore(){ echo "!! failed — rolling back"; cp -f "$F.xbak.$TS" "$F"; rm -f .ins_menu.txt .gszm_menu.js; exit 1; }
trap restore ERR
nchk(){ local i; for i in 1 2 3 4 5; do node --check "$F" 2>/dev/null && return 0; sleep 1; done; echo "  node --check failing; menu region:"; grep -nE "ownsess|stage|_sget|_qty" "$F" | cat -A | head; return 1; }

echo "==> writing menu-flow block (raw file)"
cat > .ins_menu.txt <<'INS'
    const _skey = 'ownsess_owner';
    const _sget = async () => { try { const r = (await pool.query("SELECT value FROM wa_settings WHERE key=$1", [_skey])).rows[0]; return r && r.value ? JSON.parse(r.value) : null; } catch (e) { return null; } };
    const _sset = async (v) => { try { await pool.query("INSERT INTO wa_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO UPDATE SET value=$2, updated_at=now()", [_skey, JSON.stringify(v)]); } catch (e) {} };
    const _sclr = async () => { try { await pool.query("DELETE FROM wa_settings WHERE key=$1", [_skey]); } catch (e) {} };
    if (/^(cancel|x|exit|stop)$/i.test(t)) { await _sclr(); return 'Cancelled. Send menu to start again.'; }
    if (/^(m|menu|sell|buy)$/i.test(t)) {
      const rws = (await pool.query("SELECT pl.id, pr.name AS pn, pl.label, pl.price_pkr, pl.price_usd, (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.source='inventory' ORDER BY pr.name, pl.sort, pl.id")).rows.filter(function (r) { return r.avail > 0; });
      if (!rws.length) return 'No own-stock available right now. Add with: addstock <planId>';
      const map = {}; const lines = rws.map(function (r, i) { map[i + 1] = r.id; var price = 'Rs ' + Math.round(r.price_pkr || 0); if (r.price_usd) price += ' / $' + Number(r.price_usd).toFixed(2); return (i + 1) + '. ' + r.pn + ' — ' + r.label + '  (' + price + ')  · ' + r.avail + ' in stock'; });
      await _sset({ stage: 'pick', map: map, ts: Date.now() });
      return ['🛒 Choose a product to sell', ''].concat(lines).concat(['', 'Reply with the number (or cancel).']).join('\n');
    }
    { const _sess = await _sget();
      if (_sess && _sess.ts && (Date.now() - _sess.ts) < 600000) {
        if (_sess.stage === 'pick' && /^\d+$/.test(t)) {
          const _pid = _sess.map && _sess.map[t];
          if (!_pid) return 'Invalid number. Send menu to see the list again.';
          const _pl = (await pool.query("SELECT pl.id, pr.name AS pn, pl.label, (SELECT count(*)::int FROM inventory_items i WHERE i.plan_id=pl.id AND i.status='available') AS avail FROM product_plans pl JOIN products pr ON pr.id=pl.product_id WHERE pl.id=$1", [_pid])).rows[0];
          if (!_pl || _pl.avail < 1) { await _sclr(); return 'That item is out of stock now. Send menu again.'; }
          await _sset({ stage: 'qty', planId: _pid, name: _pl.pn + ' — ' + _pl.label, avail: _pl.avail, ts: Date.now() });
          return _pl.pn + ' — ' + _pl.label + '\n' + _pl.avail + ' available.\n\nHow many do you want? (reply a number, or cancel)';
        }
        if (_sess.stage === 'qty' && /^\d+$/.test(t)) {
          var _qty = Math.min(parseInt(t, 10), 50); if (_qty < 1) return 'Send a quantity of 1 or more, or cancel.';
          const _pid = _sess.planId; const _out = [];
          for (var _k = 0; _k < _qty; _k++) { const _ref = 'MANUAL-' + Date.now().toString(36).toUpperCase() + '-' + (_k + 1); const _g = (await pool.query("UPDATE inventory_items SET status='delivered', order_no=$1, delivered_at=now() WHERE id=(SELECT id FROM inventory_items WHERE plan_id=$2 AND status='available' ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED) RETURNING payload", [_ref, _pid])).rows[0]; if (!_g) break; _out.push(_g.payload); }
          await _sclr();
          if (!_out.length) return 'Out of stock — nothing delivered. Send menu again.';
          const _left = (await pool.query("SELECT count(*)::int n FROM inventory_items WHERE plan_id=$1 AND status='available'", [_pid])).rows[0].n;
          const _head = ['✅ Delivered ' + _out.length + (_qty > _out.length ? (' of ' + _qty + ' (stock ran out)') : '') + ' — ' + _sess.name, '(' + _left + ' left · marked SOLD on website)'];
          return _head.concat(_out.map(function (p, i) { return '— Unit ' + (i + 1) + ' —\n' + p; })).join('\n\n');
        }
      }
    }
INS

echo "==> inserting menu flow at top of ownerCommand"
cat > .gszm_menu.js <<'JS'
var fs = require('fs');
var f = 'routes/whatsapp.js';
var s = fs.readFileSync(f, 'utf8');
var blk = fs.readFileSync('.ins_menu.txt', 'utf8').replace(/\n$/, '');
var a = "    const t = String(text || '').trim();";
var n = s.split(a).length - 1;
if (n !== 1) { console.log('  ANCHOR x' + n + ' — aborting (no change)'); process.exit(2); }
s = s.split(a).join(a + '\n' + blk);
fs.writeFileSync(f, s);
console.log('  menu flow inserted');
process.exit(0);
JS
node .gszm_menu.js
nchk
rm -f .ins_menu.txt .gszm_menu.js
echo "   check passed"

echo "==> restart + health"
pm2 restart "$APP" >/dev/null 2>&1; sleep 2
ok=0; for i in $(seq 1 10); do curl -sf "http://127.0.0.1:$PORT/admin/login" >/dev/null 2>&1 && { ok=1; break; }; sleep 1; done
[ "$ok" = "1" ] || { echo "health check failed on :$PORT"; false; }
trap - ERR
echo "DONE — send 'menu' (or m) to the bot: pick number -> quantity -> delivered + marked SOLD."
