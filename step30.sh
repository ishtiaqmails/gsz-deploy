#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON — STEP 30: correct catalog mapping + save-safe UI
#  1) views/admin/mapping.ejs : Save now submits ONLY the rows you changed,
#     so a stale page / untouched row can never wipe good mappings again.
#     Warns if a row is "Reseller bot" with no product chosen.
#  2) Migration: re-map 54 products to their REAL bot SKU (matched by name).
#     Left MANUAL on purpose (handled in the Profiles/Full-Accounts step):
#       Netflix Premium, Prime Video (profile plans), HBO Max 1-Year-5-Profiles.
#  Backs up the current mapping to table mapping_backup_s30. Auto-rollback.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -f "$APP/views/admin/mapping.ejs" ] || { echo "ABORT: mapping.ejs not found"; exit 1; }
cd "$APP"
set -a; . "$APP/.env"; set +a

TS=$(date +%s)
BK="$APP/.bak-step30-$TS"; mkdir -p "$BK"
cp views/admin/mapping.ejs "$BK/mapping.ejs"
restore(){ echo "!! ROLLBACK"; cp "$BK/mapping.ejs" "$APP/views/admin/mapping.ejs" 2>/dev/null||true; pm2 restart gsz >/dev/null 2>&1||true; }
trap 'restore' ERR

echo "== Galaxy Subz x Zayron — Step 30 (catalog mapping + save-safe) =="

cat > views/admin/mapping.ejs <<'EOF_MAP'
<%- include('_shell_top', { active:'mapping', title:'Bot mapping' }) %>
<style>
  .mapwrap{overflow-x:auto}
  table.map{min-width:880px}
  table.map td{vertical-align:middle}
  table.map select{margin-bottom:0}
  .plan-name{font-weight:700}
  .plan-price{color:var(--muted);font-size:12.5px}
  .src-pill{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:700}
  .badge{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:700;border-radius:999px;padding:3px 9px;white-space:nowrap}
  .badge.ok{background:#e9fbf1;color:#0b7a42}
  .badge.warn{background:#fff4e2;color:#9a6400}
  .badge.bad{background:#fdeceb;color:#b4322c}
  .badge.mut{background:#eef1fa;color:#5b6688}
  .botcell[hidden]{display:none}
  .conn{display:flex;align-items:center;gap:14px;flex-wrap:wrap}
  .dot{width:9px;height:9px;border-radius:50%;flex:none}
  .dot.g{background:var(--ok)} .dot.r{background:var(--bad)} .dot.y{background:var(--warn)}
  tr.mismatch td{background:#fff6f6}
</style>

<% if (flash) { %><div class="flash"><%= flash %></div><% } %>

<!-- connection status -->
<div class="card">
  <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap">
    <div class="conn">
      <% var dotc = !bot.configured ? 'y' : (bot.reachable ? 'g' : 'r'); %>
      <span class="dot <%= dotc %>"></span>
      <div>
        <b>Reseller bot link:
          <%= !bot.configured ? 'not configured yet' : (bot.reachable ? 'connected' : 'unreachable') %></b>
        <div class="sub" style="margin:2px 0 0">
          <% if (!bot.configured) { %>
            Add <code>GSZ_BOT_API_URL</code> + <code>GSZ_BOT_API_KEY</code> to <code>.env</code>, then Sync.
          <% } else if (!bot.reachable) { %>
            Configured but the API didn't answer<%= bot.error ? ' ('+bot.error+')' : '' %>.
          <% } else { %>
            <%= bot.productCount %> products live on the bot.
          <% } %>
          · <%= bot.count %> cached<% if (bot.missing) { %> · <span style="color:var(--bad);font-weight:700"><%= bot.missing %> missing</span><% } %>
          <% if (bot.last_sync) { %> · last sync <%= new Date(bot.last_sync).toLocaleString('en-GB') %><% } %>
        </div>
      </div>
    </div>
    <form method="post" action="/admin/bot/sync" style="margin:0">
      <button class="btn btn-g" type="submit">↻ Sync from bot</button>
    </form>
  </div>
</div>

<p class="sub" style="margin:0 0 14px">
  Choose how each plan is fulfilled. <b>Reseller bot</b> maps to the bot's immutable <code>sku</code> (+ plan &amp; type for IPTV),
  so renaming or re-ordering products on the bot never breaks it. <b>My inventory</b> delivers from this site's own stock pool.
  <b>Manual</b> = you deliver by hand. Pick a bot product and the source switches to <b>Reseller bot</b> automatically.
</p>

<div class="card" style="display:flex;align-items:center;gap:12px;flex-wrap:wrap;margin-bottom:16px">
  <button type="button" class="btn btn-g" id="automap">✨ Auto-map by name</button>
  <span class="sub" id="automap-note">Suggests the matching bot product for every unmapped / mismatched plan. Review, then Save.</span>
</div>

<form method="post" action="/admin/mapping">
<% products.forEach(function(p){ var plans=(byProd[p.id]||[]); if(!plans.length) return; %>
  <div class="card">
    <h2 style="margin:0 0 2px"><%= p.name %></h2>
    <div class="sub" style="margin:0 0 14px"><%= p.cat || '—' %> · <%= plans.length %> plan<%= plans.length>1?'s':'' %></div>
    <div class="mapwrap">
      <table class="map">
        <thead><tr>
          <th style="width:190px">Plan</th><th style="width:150px">Source</th>
          <th>Bot product</th><th style="width:150px">Bot plan</th><th style="width:130px">Type</th>
          <th style="width:160px">Status</th>
        </tr></thead>
        <tbody>
        <% plans.forEach(function(pl){ var isBot = pl.source==='bot'; %>
          <tr data-plan="<%= pl.id %>" data-pname="<%= p.name.replace(/"/g,'&quot;') %>">
            <td><div class="plan-name"><%= pl.label %></div><div class="plan-price">Rs <%= Math.round(pl.price_pkr).toLocaleString('en-US') %></div></td>
            <td>
              <select name="pl[<%= pl.id %>][source]" class="js-src">
                <option value="manual"    <%= pl.source==='manual'    ?'selected':'' %>>Manual</option>
                <option value="inventory" <%= pl.source==='inventory' ?'selected':'' %>>My inventory</option>
                <option value="bot"       <%= pl.source==='bot'       ?'selected':'' %>>Reseller bot</option>
              </select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_sku]" class="js-sku">
                <option value="">— choose product —</option>
                <% bots.forEach(function(b){ %>
                  <option value="<%= b.sku %>" <%= pl.bot_sku===b.sku?'selected':'' %>>
                    <%= b.name || b.sku %><%= b.missing?' (MISSING)':'' %> · <%= b.sku %></option>
                <% }); %>
              </select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_plan_key]" class="js-plan" data-cur="<%= pl.bot_plan_key||'' %>"></select>
            </td>
            <td class="botcell" <%= isBot?'':'hidden' %>>
              <select name="pl[<%= pl.id %>][bot_type]" class="js-type" data-cur="<%= pl.bot_type||'' %>"></select>
            </td>
            <td><span class="badge mut js-status">—</span></td>
          </tr>
        <% }); %>
        </tbody>
      </table>
    </div>
  </div>
<% }); %>

  <div style="position:sticky;bottom:0;padding:14px 0;background:linear-gradient(0deg,var(--bg) 55%,transparent)">
    <button class="btn btn-p" type="submit">Save mapping</button>
    <span class="sub" style="margin-left:12px">Pricing &amp; stock stay live from the bot; this only sets the fulfilment route.</span>
  </div>
</form>

<script>
var BOT = <%- JSON.stringify(botBySku || {}) %>;
function opt(v,label,sel){ var o=document.createElement('option'); o.value=v; o.textContent=label; if(sel)o.selected=true; return o; }

// ---- name matching (so a wrong SKU is impossible to miss, + auto-map) ----
function norm(s){ return String(s||'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim(); }
function toks(s){ return norm(s).split(' ').filter(function(w){ return w.length>1; }); }
function nameMatch(pName,bName){
  var a=norm(pName), b=norm(bName);
  if(!a||!b) return false;
  if(b.indexOf(a)>=0 || a.indexOf(b)>=0) return true;
  var pt=toks(pName), bt=toks(bName);
  if(!pt.length) return false;
  var common=pt.filter(function(t){ return bt.indexOf(t)>=0; }).length;
  return (common/pt.length) >= 0.6;
}
function bestSku(pName){
  var pt=toks(pName), best=null, bestScore=0;
  Object.keys(BOT).forEach(function(sku){
    var b=BOT[sku]; if(!b||b.missing) return;
    var bt=toks(b.name||'');
    var common=pt.length ? pt.filter(function(t){ return bt.indexOf(t)>=0; }).length / pt.length : 0;
    var score=common;
    if(norm(b.name).indexOf(norm(pName))>=0) score += 0.5;
    if(score>bestScore){ bestScore=score; best=sku; }
  });
  return bestScore>=0.6 ? best : null;
}

function fillPlanType(row){
  var sku=row.querySelector('.js-sku').value;
  var planSel=row.querySelector('.js-plan'), typeSel=row.querySelector('.js-type');
  var b=BOT[sku];
  var curPlan=planSel.getAttribute('data-cur')||'', curType=typeSel.getAttribute('data-cur')||'';
  planSel.innerHTML=''; typeSel.innerHTML='';
  var plans=(b&&b.plans)||[], types=(b&&b.types)||[];
  if(!plans.length){ planSel.appendChild(opt('','— n/a —',true)); planSel.disabled=true; }
  else { planSel.disabled=false; planSel.appendChild(opt('','— choose —',!curPlan));
    plans.forEach(function(p){ planSel.appendChild(opt(p.plan_key, p.label+(p.price!=null?(' · Rs '+p.price):''), String(p.plan_key)===curPlan)); }); }
  if(!types.length){ typeSel.appendChild(opt('','— n/a —',true)); typeSel.disabled=true; }
  else { typeSel.disabled=false; typeSel.appendChild(opt('','— choose —',!curType));
    types.forEach(function(t){ typeSel.appendChild(opt(t.key, t.label||t.key, String(t.key)===curType)); }); }
}
function status(row){
  var src=row.querySelector('.js-src').value, el=row.querySelector('.js-status');
  el.className='badge'; row.classList.remove('mismatch');
  if(src==='manual'){ el.classList.add('mut'); el.textContent='Manual'; return; }
  if(src==='inventory'){ el.classList.add('mut'); el.textContent='Own inventory'; return; }
  var sku=row.querySelector('.js-sku').value, b=BOT[sku];
  if(!sku){ el.classList.add('warn'); el.textContent='⚠ not mapped'; return; }
  if(!b){ el.classList.add('warn'); el.textContent='⚠ sync needed'; return; }
  if(b.missing){ el.classList.add('bad'); el.textContent='⚠ missing on bot'; return; }
  var pName=row.getAttribute('data-pname')||'';
  if(pName && !nameMatch(pName, b.name||'')){ el.classList.add('bad'); el.textContent='⚠ name mismatch'; row.classList.add('mismatch'); return; }
  el.classList.add('ok'); el.textContent=(b.delivery_type||'mapped');
}
function sync(row){
  var src=row.querySelector('.js-src').value;
  row.querySelectorAll('.botcell').forEach(function(c){ c.hidden = (src!=='bot'); });
  if(src==='bot') fillPlanType(row);
  status(row);
}
function setBot(row, sku){
  row.querySelector('.js-src').value='bot';
  row.querySelectorAll('.botcell').forEach(function(c){ c.hidden=false; });
  var skuSel=row.querySelector('.js-sku'); skuSel.value=sku;
  row.querySelector('.js-plan').setAttribute('data-cur','');
  row.querySelector('.js-type').setAttribute('data-cur','');
  fillPlanType(row); status(row);
}
document.querySelectorAll('tr[data-plan]').forEach(function(row){
  sync(row);
  row.querySelector('.js-src').addEventListener('change',function(){
    // switching away from bot clears any leftover SKU so it can't be saved by mistake
    if(this.value!=='bot'){
      row.querySelector('.js-sku').value='';
      row.querySelector('.js-plan').setAttribute('data-cur','');
      row.querySelector('.js-type').setAttribute('data-cur','');
    }
    sync(row);
  });
  row.querySelector('.js-sku').addEventListener('change',function(){
    // picking a bot product IS a bot mapping — flip the source so what you see is what saves
    if(this.value){ row.querySelector('.js-src').value='bot'; }
    row.querySelectorAll('.botcell').forEach(function(c){ c.hidden=false; });
    row.querySelector('.js-plan').setAttribute('data-cur','');
    row.querySelector('.js-type').setAttribute('data-cur','');
    fillPlanType(row); status(row);
  });
});

// ---- Auto-map by name ----
document.getElementById('automap').addEventListener('click',function(){
  var mapped=0, skipped=0;
  document.querySelectorAll('tr[data-plan]').forEach(function(row){
    var src=row.querySelector('.js-src').value;
    var curSku=row.querySelector('.js-sku').value;
    var pName=row.getAttribute('data-pname')||'';
    // only touch rows that are unmapped, or bot-but-mismatched; never overwrite a good match or inventory
    var isGood = (src==='bot' && curSku && BOT[curSku] && !BOT[curSku].missing && nameMatch(pName, BOT[curSku].name||''));
    if(src==='inventory' || isGood){ return; }
    var sku=bestSku(pName);
    if(sku){ setBot(row, sku); mapped++; } else { skipped++; }
  });
  var note=document.getElementById('automap-note');
  note.textContent='Suggested '+mapped+' mapping'+(mapped===1?'':'s')+(skipped?(' · '+skipped+' had no confident match'):'')+'. Review the rows, then click Save mapping.';
});

// ---- stale-safe submit: only send the rows the admin actually changed ----
(function(){
  var allrows=[].slice.call(document.querySelectorAll('tr[data-plan]'));
  function val(row,sel){ var el=row.querySelector(sel); return el ? (el.value||'') : ''; }
  allrows.forEach(function(row){
    row.dataset.oSrc=val(row,'.js-src'); row.dataset.oSku=val(row,'.js-sku');
    row.dataset.oPlan=val(row,'.js-plan'); row.dataset.oType=val(row,'.js-type');
    ['.js-src','.js-sku','.js-plan','.js-type'].forEach(function(s){ var el=row.querySelector(s); if(el) el.addEventListener('change',function(){ row.dataset.touched='1'; }); });
  });
  var form=document.querySelector('form[action="/admin/mapping"]');
  if(form) form.addEventListener('submit', function(e){
    var warn=[];
    allrows.forEach(function(row){
      var changed = row.dataset.touched==='1' || val(row,'.js-src')!==row.dataset.oSrc || val(row,'.js-sku')!==row.dataset.oSku || val(row,'.js-plan')!==row.dataset.oPlan || val(row,'.js-type')!==row.dataset.oType;
      if(changed && val(row,'.js-src')==='bot' && !val(row,'.js-sku')) warn.push(row.getAttribute('data-pname'));
      if(!changed){ ['.js-src','.js-sku','.js-plan','.js-type'].forEach(function(s){ var el=row.querySelector(s); if(el) el.disabled=true; }); }
    });
    if(warn.length){
      if(!confirm('These rows are set to Reseller bot but have no product chosen:\n\n'+warn.join(', ')+'\n\nSave anyway? They will show as "not mapped".')){
        allrows.forEach(function(row){ ['.js-src','.js-sku'].forEach(function(s){ var el=row.querySelector(s); if(el) el.disabled=false; }); });
        e.preventDefault();
      }
    }
  });
})();
</script>

<%- include('_shell_bottom') %>
EOF_MAP

node -e '
const ejs=require("ejs"),fs=require("fs");
try{ ejs.compile(fs.readFileSync("views/admin/mapping.ejs","utf8"),{filename:"views/admin/mapping.ejs"}); console.log("[ok] mapping.ejs compiles"); }
catch(e){ console.error("ABORT: mapping.ejs",e.message); process.exit(1); }
' || exit 1

# ---- migration: correct catalog mapping ----
export PGPASSWORD="$DB_PASS"
PSQL="psql -P pager=off -h ${DB_HOST:-127.0.0.1} -p ${DB_PORT:-5432} -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1"
echo "-- re-mapping catalog by name --"
$PSQL <<'SQL'
BEGIN;
CREATE TABLE IF NOT EXISTS mapping_backup_s30 AS
  SELECT pl.id, p.name AS product, pl.label, pl.source AS old_source, pl.bot_sku AS old_sku, now() AS saved
  FROM product_plans pl JOIN products p ON p.id=pl.product_id;
-- single-plan products -> their real bot SKU
UPDATE product_plans pl SET source='bot', bot_sku=m.sku, bot_plan_key=NULL, bot_type=NULL
FROM (VALUES
 ('Peacock TV','SKU-00061'),('Hilal Play','SKU-00063'),('BritBox','SKU-00064'),
 ('Zee5','SKU-00065'),('Crave','SKU-00067'),('ShemarooMe','SKU-00068'),
 ('KableOne','SKU-00069'),('Eros Now','SKU-00070'),('AMC+','SKU-00071'),
 ('StarZ','SKU-00072'),('Hotstar','SKU-00084'),('Tabii','SKU-00113'),
 ('KOCOWA+','SKU-00112'),('MGM+','SKU-00111'),('Hallmark+','SKU-00139'),
 ('Rakuten Viki','SKU-00152'),('Curiosity Stream','SKU-00153'),('ESPN+','SKU-00073'),
 ('F1 TV','SKU-00074'),('Disney+ (No Ads)','SKU-00058'),('Hulu (No Ads)','SKU-00059'),
 ('Paramount+ (No Ads) USA','SKU-00060'),('StarShare TV','SKU-00101'),('B1G TV','SKU-00036'),
 ('Geo IPTV','SKU-00038'),('5G Live / Zain TV','SKU-00039'),('Mega OTT','SKU-00097'),
 ('Rolex TV','SKU-00041'),('Filex IPTV','SKU-00042'),('Boss TV','SKU-00043'),
 ('Zum TV','SKU-00105'),('Trex OTT','SKU-00116'),('Strong 8K','SKU-00117'),
 ('Nord VPN','SKU-00075'),('Surfshark VPN','SKU-00104'),('Mysterium VPN','SKU-00085'),
 ('Vypr VPN','SKU-00077'),('CapCut','SKU-00086'),('Envato Elements','SKU-00108'),
 ('Grammarly','SKU-00079'),('QuillBot','SKU-00080'),('Canva Edu','SKU-00095'),
 ('Gemini AI Pro','SKU-00115'),('PicsArt','SKU-00081'),('Udemy Premium','SKU-00109'),
 ('SkillShare','SKU-00082'),('Zoom Pro','SKU-00143'),('Hot Player','SKU-00141'),
 ('IBO Player','SKU-00119')
) AS m(product, sku)
JOIN products p ON p.name=m.product
WHERE pl.product_id=p.id;
-- HBO Max: only the 1-month plan -> private screen SKU
UPDATE product_plans pl SET source='bot', bot_sku='SKU-00057', bot_plan_key=NULL, bot_type=NULL
FROM products p WHERE pl.product_id=p.id AND p.name='HBO Max' AND pl.label ILIKE '%1 month%';
-- Opplex TV: all 4 duration plans -> Opplex SKU (per-duration plan_key handled later)
UPDATE product_plans pl SET source='bot', bot_sku='SKU-00030', bot_plan_key=NULL, bot_type=NULL
FROM products p WHERE pl.product_id=p.id AND p.name='Opplex TV';
COMMIT;
SELECT count(*) AS bot_plans FROM product_plans WHERE source='bot';
SELECT p.name AS product, pl.label, pl.bot_sku, b.name AS bot_product, b.delivery_type
FROM product_plans pl JOIN products p ON p.id=pl.product_id JOIN bot_products b ON b.sku=pl.bot_sku
WHERE pl.source='bot' ORDER BY b.delivery_type, p.name;
SQL
echo "[ok] catalog re-mapped"

pm2 restart gsz >/dev/null 2>&1 || pm2 start server.js --name gsz >/dev/null 2>&1
sleep 2
BODY=$(curl -fsS "http://127.0.0.1:${PORT:-3900}/" 2>/dev/null || true)
if grep -q "</html>" <<< "$BODY"; then echo "[ok] site responding on ${PORT:-3900}"; else echo "!! health soft-fail"; fi

trap - ERR
echo
echo "==================== STEP 30 DONE ===================="
echo " Catalog mapped correctly + Save is now change-only (no more wipes)."
echo " Still Manual (on purpose): Netflix Premium, Prime Video profiles,"
echo " HBO Max 1-Year. We handle those in the Profiles/Full-Accounts step."
echo " Backup table: mapping_backup_s30 · file backup: $BK"
echo "====================================================="
