#!/usr/bin/env bash
# Verification Bot owner commands: `library` / `library <name>` (counts+plans+prices, all IPTVs),
# `autoupdate [hours]` (view/set self-update interval), + help menu refreshed. routes/whatsapp.js only.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
ts=$(date +%s)
cp routes/whatsapp.js "routes/whatsapp.js.bak.$ts"
restore(){ echo "ROLLING BACK"; cp "routes/whatsapp.js.bak.$ts" routes/whatsapp.js; }

node <<'NODE'
const fs=require('fs');
function P(file,pairs){ let s=fs.readFileSync(file,'utf8'); for(const [a,b] of pairs){ const n=s.split(a).length-1; if(n!==1){ console.log('FAIL anchor x'+n+' ['+file+']: '+JSON.stringify(a.slice(0,70))); process.exit(1);} s=s.split(a).join(b);} fs.writeFileSync(file,s); console.log('patched '+file); }

const handlers = `      if (/^(library|lib|libs)\\b/i.test(t)) {
        const NL = String.fromCharCode(10);
        const nf = function(n){ return Number(n||0).toLocaleString('en-US'); };
        const q = t.replace(/^(library|lib|libs)\\s*/i, '').trim();
        if (!q) {
          const rows = (await pool.query("SELECT p.name, p.slug, l.live_count, l.vod_count, l.series_count, l.raw_live, l.raw_vod, l.raw_series FROM products p JOIN categories c ON c.id=p.category_id LEFT JOIN iptv_library l ON l.server_key=p.slug WHERE c.slug='iptv' AND p.active AND NOT p.hidden ORDER BY p.name")).rows;
          if (!rows.length) return 'No IPTV products found.';
          const lines = rows.map(function(r){ var lv=(+r.raw_live>0?r.raw_live:r.live_count)||0, vd=(+r.raw_vod>0?r.raw_vod:r.vod_count)||0, sr=(+r.raw_series>0?r.raw_series:r.series_count)||0; var has=(lv||vd||sr); return '• ' + r.name + (has ? (NL + '   ' + nf(lv) + ' Live · ' + nf(vd) + ' Movies · ' + nf(sr) + ' Series') : (NL + '   (library not pulled yet)')); });
          return ['📺 IPTV libraries', ''].concat(lines).concat(['', 'Details:  library <name>   (e.g. library opplex)']).join(NL);
        }
        const prow = (await pool.query("SELECT p.id, p.name, p.slug FROM products p JOIN categories c ON c.id=p.category_id WHERE c.slug='iptv' AND (p.name ILIKE $1 OR p.slug ILIKE $1) ORDER BY (p.slug ILIKE $1) DESC, p.name LIMIT 1", ['%' + q + '%'])).rows[0];
        if (!prow) return 'No IPTV matching "' + q + '". Send  library  for the full list.';
        const lib = (await pool.query("SELECT live_count, vod_count, series_count, episode_count, raw_live, raw_vod, raw_series, to_char(updated_at,'Mon DD, HH24:MI') u FROM iptv_library WHERE server_key=$1", [prow.slug])).rows[0];
        const pls = (await pool.query("SELECT label, price_pkr, price_usd FROM product_plans WHERE product_id=$1 ORDER BY sort, id", [prow.id])).rows;
        const L = ['📺 ' + prow.name, ''];
        if (lib) {
          var lv=(+lib.raw_live>0?lib.raw_live:lib.live_count)||0, vd=(+lib.raw_vod>0?lib.raw_vod:lib.vod_count)||0, sr=(+lib.raw_series>0?lib.raw_series:lib.series_count)||0;
          L.push('Live TV:  ' + nf(lv)); L.push('Movies:   ' + nf(vd)); L.push('Series:   ' + nf(sr));
          if (lib.episode_count) L.push('Episodes: ' + nf(lib.episode_count));
          if (lib.u) L.push('Updated:  ' + lib.u);
        } else { L.push('(library not pulled yet)'); }
        L.push('');
        if (pls.length) {
          L.push('Plans & prices:');
          pls.forEach(function(p){ var price = 'Rs ' + Math.round(p.price_pkr||0).toLocaleString('en-US'); if (p.price_usd) price += ' / $' + Number(p.price_usd).toFixed(2); L.push('• ' + p.label + ' — ' + price); });
        } else { L.push('(no plans set)'); }
        return L.join(NL);
      }
      if (/^(autoupdate|refresh)\\b/i.test(t)) {
        const NL = String.fromCharCode(10);
        const arg = t.replace(/^(autoupdate|refresh)\\s*/i, '').trim();
        if (arg) {
          let h = parseFloat(arg); if (!(h > 0)) return 'Usage: autoupdate <hours>   e.g. autoupdate 8';
          if (h < 1) h = 1; if (h > 240) h = 240; h = Math.round(h * 10) / 10;
          await pool.query("INSERT INTO wa_settings(key,value) VALUES('iptv_refresh_hours',$1) ON CONFLICT(key) DO UPDATE SET value=$1, updated_at=now()", [String(h)]);
          return ['✅ Auto-update set: every ' + h + ' hours.', 'Server engine + phone agent both follow this.'].join(NL);
        }
        const cur = (await pool.query("SELECT value FROM wa_settings WHERE key='iptv_refresh_hours'")).rows[0];
        const hv = cur ? parseFloat(cur.value) : 12;
        return ['🔄 Auto-update: every ' + (hv > 0 ? hv : 12) + ' hours.', '', 'Change it:  autoupdate <hours>   (e.g. autoupdate 8)'].join(NL);
      }
      if (/^stock\\b/i.test(t)) {`;

P('routes/whatsapp.js',[
[`      if (/^stock\\b/i.test(t)) {`, handlers],
[`'','📊 Orders','• orders — today totals + latest'`,
 `'','📺 IPTV','• library — all IPTV panels + their counts','• library <name> — one IPTV: counts, plans, prices','• autoupdate [hours] — view/set library refresh','','📊 Orders','• orders — today totals + latest'`]
]);
NODE
if [ $? -ne 0 ]; then restore; exit 1; fi

echo "== JS syntax =="
node -c routes/whatsapp.js && echo "JS OK" || { restore; exit 1; }

echo "== restart =="
pm2 restart gsz --update-env
sleep 2
pm2 list | grep -iE "gsz "
echo DONE
