#!/usr/bin/env bash
# stepZayronBotSku2 — ADMIN mapping UI: on the server edit form, add a "Bot product" dropdown
# (fed live from gsz-api /api/products) so the owner maps each server -> its bot product (sku).
# Saved via the existing cols{} builder (covers both new + edit). Purely admin-side; the public
# site + provisioning are untouched by this step. Safe: backup, single-match anchors, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zbs2; rm -rf "$W"; mkdir -p "$W/p"
cp routes/admin.js "$W/admin.js.bak"
revert(){ cp "$W/admin.js.bak" routes/admin.js; }

# ---- 1) fetch bot products alongside _panels in the edit handler ----
cat > "$W/p/o1" <<'OLD'
  let _panels = []; try { _panels = await getPanels(); } catch (e) { _panels = []; }
OLD
cat > "$W/p/n1" <<'NEW'
  let _panels = []; try { _panels = await getPanels(); } catch (e) { _panels = []; }
  let _botProducts = []; try { const _pp = await require('../lib/gszApi').getProducts(); _botProducts = ((_pp && _pp.products) || []).filter(function (p) { return p.delivery_type === 'iptv'; }); } catch (e) { _botProducts = []; }
NEW

# ---- 2) render the Bot product dropdown right under the Panel field ----
cat > "$W/p/o2" <<'OLD'
        <p class="hint">Pick the panel this website provider maps to. The bot creates the trial from this panel. Leave as "None" to keep trials manual (customer messages you on WhatsApp).</p>
      </div>
OLD
cat > "$W/p/n2" <<'NEW'
        <p class="hint">Pick the panel this website provider maps to. The bot creates the trial from this panel. Leave as "None" to keep trials manual (customer messages you on WhatsApp).</p>
      </div>
      <div><label>Bot product <span class="muted">(which bot product fulfils PAID lines for this server)</span></label>
        <select name="bot_sku" style="max-width:340px">
          <option value="">— Not mapped (paid orders wait for manual review) —</option>
          ${_botProducts.map(function(p){ return '<option value="'+esc(p.sku)+'"'+(String(s.bot_sku||'')===String(p.sku)?' selected':'')+'>'+esc(p.name)+' ('+esc(p.sku)+')</option>'; }).join('')}
        </select>
        <p class="hint">Map this website server to its product on the bot. Paid orders then provision automatically through it. Plans match by name (1 Month, 3 Months, 1 Year). Leave unmapped to keep paid orders manual.</p>
      </div>
NEW

# ---- 3) persist bot_sku on save (covers new + edit via cols{}) ----
cat > "$W/p/o3" <<'OLD'
      reseller_pid: (b.reseller_pid||'').trim(),
      trial_package_id: (b.trial_package_id||'').trim(),
OLD
cat > "$W/p/n3" <<'NEW'
      reseller_pid: (b.reseller_pid||'').trim(),
      trial_package_id: (b.trial_package_id||'').trim(),
      bot_sku: (b.bot_sku||'').trim() || null,
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zbs2/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/admin.js','o1','n1');
rep('routes/admin.js','o2','n2');
rep('routes/admin.js','o3','n3');
console.log('admin.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: admin server edit now has a 'Bot product' dropdown. Map each server, then step 3 wires provisioning to it."
