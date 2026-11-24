#!/usr/bin/env bash
# READ-ONLY. Why isTrialDisabled now returns disabled for mapped servers (empty providers).
Z=/opt/zayron; cd "$Z"
echo "### where isTrialDisabled / panelSellable / _skuFor are defined ###"
grep -rnE "isTrialDisabled|panelSellable|_skuFor|function.*[Tt]rial[Dd]isabled" lib/ | grep -viE "\.bak" | head
echo
echo "### lib/panels.js (full) ###"
cat -n lib/panels.js 2>/dev/null | head -80
echo
echo "### live: products + 5G Zain flag + isTrialDisabled ###"
node -e '
const gszApi=require("./lib/gszApi");
(async()=>{
  const prods=await gszApi.getProducts();
  console.log("products is array:", Array.isArray(prods), "len:", (prods||[]).length);
  const p=(prods||[]).find(x=>String(x.sku)==="SKU-00039");
  console.log("SKU-00039 product:", JSON.stringify(p));
  console.log("sample product keys:", prods&&prods[0]?Object.keys(prods[0]):"(none)");
  process.exit(0);
})().catch(e=>{console.error("ERR:",e.message);process.exit(1)});
'
echo DONE
