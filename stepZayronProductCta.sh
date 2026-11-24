#!/usr/bin/env bash
# stepZayronProductCta — the product page computed autoTrial/autoPaid but never rendered them (it was
# reverted to a hardcoded "Order on WhatsApp" when the store was switched off). Wire the CTA to the
# live flags: Buy now (-> /checkout) when autoPaid, Free trial (-> /trial/start) when autoTrial, and
# fall back to Order on WhatsApp when neither. Buy button tracks the selected plan.
# Safe: backup, single-match anchors + auto-revert, node --check, restart (clears getPublicData cache).
set -e
Z=/opt/zayron; cd "$Z"
W=/tmp/zpc; rm -rf "$W"; mkdir -p "$W/p"
cp server.js "$W/server.js.bak"
revert(){ cp "$W/server.js.bak" server.js; }

# ---- 1) build the CTA from autoPaid/autoTrial (replaces the blank trialBtn) ----
cat > "$W/p/o1" <<'OLD'
  const trialBtn = '';
OLD
cat > "$W/p/n1" <<'NEW'
  let ctaHtml;
  if (autoPaid || autoTrial) {
    const _firstLabel = planList[0] ? planList[0].l : '';
    const buyBtn = autoPaid ? ('<a class="btn" id="buyBtn" href="/checkout?s=' + escAttr(s.slug) + '&plan=' + encodeURIComponent(_firstLabel) + '&ct=family">Buy now</a>') : '';
    const trBtn = autoTrial ? ('<a class="btn ghost" id="freeTrialBtn" href="/trial/start?s=' + escAttr(s.slug) + '">Free trial</a>') : '';
    ctaHtml = '<div class="pdp-cta" style="display:flex;gap:10px;flex-wrap:wrap">' + buyBtn + trBtn + '</div>';
  } else {
    ctaHtml = '<div class="pdp-cta"><a class="btn wa" href="/contact" id="orderBtn">Order on WhatsApp</a></div>';
  }
NEW

# ---- 2) render the CTA in place of the hardcoded WhatsApp button ----
cat > "$W/p/o2" <<'OLD'
      <div class="pdp-cta"><a class="btn wa" href="/contact" id="orderBtn">Order on WhatsApp</a></div>
OLD
cat > "$W/p/n2" <<'NEW'
      ${ctaHtml}
NEW

# ---- 3) keep the Buy button's plan in sync with the picker ----
cat > "$W/p/o3" <<'OLD'
    if(sel)sel.addEventListener('change',function(){cur=planData[this.value]||cur;var bp=document.getElementById('bigPrice');if(bp)bp.textContent=cur.disp;});
OLD
cat > "$W/p/n3" <<'NEW'
    if(sel)sel.addEventListener('change',function(){cur=planData[this.value]||cur;var bp=document.getElementById('bigPrice');if(bp)bp.textContent=cur.disp;var bb=document.getElementById('buyBtn');if(bb)bb.href='/checkout?s='+${JSON.stringify(s.slug)}+'&plan='+encodeURIComponent(cur.l)+'&ct=family';});
NEW

cat > "$W/apply.js" <<'APPLY'
const fs = require('fs'); const P = '/tmp/zpc/p/';
function rd(f){ return fs.readFileSync(f,'utf8').replace(/\n$/,''); }
function rep(file,oF,nF){ let s=fs.readFileSync(file,'utf8'); const o=rd(P+oF), n=rd(P+nF); const c=s.split(o).length-1; if(c!==1){ console.error('ANCHOR x'+c+' ['+oF+']'); process.exit(5);} fs.writeFileSync(file, s.split(o).join(n)); }
rep('server.js','o1','n1');
rep('server.js','o2','n2');
rep('server.js','o3','n3');
console.log('server.js PATCHED OK');
APPLY

node "$W/apply.js" || { echo "patch failed - reverting"; revert; exit 1; }
node --check server.js || { echo "syntax error - reverting"; revert; exit 1; }

pm2 restart zayron >/dev/null 2>&1 || pm2 restart zayron
echo "DONE: product pages now show Buy now / Free trial on mapped+enabled servers (manual fallback otherwise)."
