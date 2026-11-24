#!/usr/bin/env bash
# stepZayronAdminSimplify1 — simplify the server-edit page: remove the redundant/legacy "Panel"
# (reseller_pid) dropdown. The single "Bot product" mapping now drives both paid delivery AND trials,
# so the panel field just confused things (and its empty dropdown was wiping reseller_pid on save).
# Stops writing reseller_pid on save (existing values preserved), drops the now-unused getPanels.
# Safe: backup, single-match anchors + auto-revert, node --check.
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zas; rm -rf "$W"; mkdir -p "$W/p"
cp routes/admin.js "$W/admin.js.bak"
revert(){ cp "$W/admin.js.bak" routes/admin.js; }

# ---- 1) drop the getPanels import ----
cat > "$W/p/o1" <<'OLD'
const { getPanels } = require('../lib/panels');
OLD
: > "$W/p/n1"

# ---- 2) drop the _panels fetch in the edit handler ----
cat > "$W/p/o2" <<'OLD'
  let _panels = []; try { _panels = await getPanels(); } catch (e) { _panels = []; }
OLD
: > "$W/p/n2"

# ---- 3) clearer card intro (paid + trials via the Bot product) ----
cat > "$W/p/o3" <<'OLD'
    <div class="card"><label style="margin-top:0">Free Trial Automation <span class="muted">(website self-serve trial)</span></label><p class="muted" style="margin-top:0">Fill in the <b>Reseller Product ID</b> to turn on the automated website trial for this server. Leave it blank to keep trials manual (customer messages you on WhatsApp).</p>
OLD
cat > "$W/p/n3" <<'NEW'
    <div class="card"><label style="margin-top:0">Automation <span class="muted">(paid lines + free trials)</span></label><p class="muted" style="margin-top:0">Pick this server's <b>Bot product</b> below to turn on automated paid delivery <i>and</i> trials. Leave it unmapped to keep this server manual (customer messages you on WhatsApp).</p>
NEW

# ---- 4) remove the legacy Panel dropdown block ----
cat > "$W/p/o4" <<'OLD'
      <div><label>Panel <span class="muted">(which IPTV panel makes this trial)</span></label>
        <select name="reseller_pid" style="max-width:340px">
          <option value="">— None (manual WhatsApp trial) —</option>
          ${_panels.map(function(p){ return '<option value="'+esc(p.id)+'"'+(String(s.reseller_pid||'')===p.id?' selected':'')+'>'+esc(p.name)+'</option>'; }).join('')}
        </select>
        <p class="hint">Pick the panel this website provider maps to. The bot creates the trial from this panel. Leave as "None" to keep trials manual (customer messages you on WhatsApp).</p>
      </div>
OLD
: > "$W/p/n4"

# ---- 5) stop writing reseller_pid on save (preserve existing values) ----
cat > "$W/p/o5" <<'OLD'
      reseller_pid: (b.reseller_pid||'').trim(),
      trial_package_id: (b.trial_package_id||'').trim(),
OLD
cat > "$W/p/n5" <<'NEW'
      trial_package_id: (b.trial_package_id||'').trim(),
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zas/p/';
function rd(f){ try { return fs.readFileSync(f,'utf8').replace(/\n$/,''); } catch(e){ return ''; } }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); if(!o){ console.error('empty anchor '+oF); process.exit(6);} const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('routes/admin.js','o1','n1');
rep('routes/admin.js','o2','n2');
rep('routes/admin.js','o3','n3');
rep('routes/admin.js','o4','n4');
rep('routes/admin.js','o5','n5');
console.log('admin.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check routes/admin.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: server-edit simplified — one 'Bot product' mapping drives paid + trials; legacy Panel field gone."
