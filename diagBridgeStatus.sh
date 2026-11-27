#!/usr/bin/env bash
# diagBridgeStatus — what live status/availability the reseller bot already exposes to the websites (getProducts full
# shape, ping, getStock, isTrialDisabled source), to decide if live server status can be built with no bot change. READ-ONLY.
set +e
cd /opt/zayron || exit 0
echo "### live getProducts() — full shape of one product (status/available/stock flags?) ###"
node -e "const g=require('./lib/gszApi');g.getProducts().then(j=>{const p=(j&&j.products)||[];console.log('products:',p.length);if(p[0])console.log('sample keys:',Object.keys(p[0]).join(', '));if(p[0])console.log(JSON.stringify(p[0],null,1).slice(0,900));}).catch(e=>console.log('ERR',e.message));" 2>&1 | tail -30
echo
echo "### ping() — what it returns ###"
node -e "const g=require('/opt/gsz/lib/botapi');(g.ping?g.ping():Promise.resolve('no ping')).then(r=>console.log('ping ->',JSON.stringify(r))).catch(e=>console.log('ping ERR',e.message));" 2>&1 | tail -3
echo
echo "### isTrialDisabled source (per-panel availability signal?) ###"
cd /opt/zayron && grep -rn "function isTrialDisabled\|isTrialDisabled" lib routes 2>/dev/null | grep -v node_modules | grep -iv "\.bak" | head -3
F=$(grep -rln "function isTrialDisabled" lib 2>/dev/null | head -1); [ -n "$F" ] && { echo "--- $F ---"; grep -n "isTrialDisabled" "$F"; sed -n "$(grep -n 'function isTrialDisabled\|isTrialDisabled =' "$F" | head -1 | cut -d: -f1),+12p" "$F"; }
echo
echo "### does getProducts expose a panel id / grouping (to group servers by panel)? ###"
node -e "const g=require('./lib/gszApi');g.getProducts().then(j=>{const p=(j&&j.products)||[];const pid=p.filter(x=>x.iptv_panel_id!=null).map(x=>x.iptv_panel_id);console.log('products with iptv_panel_id:',pid.length,'distinct panels:',[...new Set(pid)].join(','));}).catch(e=>console.log('ERR',e.message));" 2>&1 | tail -3
echo DONE
