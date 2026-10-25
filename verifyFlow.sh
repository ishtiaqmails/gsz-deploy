#!/usr/bin/env bash
# verifyFlow.sh — read-only. Confirms the full chain actually fires:
#   1) completing WhatsApp verification creates/activates the ACTIVE+primary
#      customer_whatsapp_links row that delivery looks up;
#   2) deliver.js sends BOTH email and WhatsApp.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "###### 1) verification -> customer_whatsapp_links (must create ACTIVE + is_primary) ######"
W="$GSZ/routes/whatsapp.js"
echo "FILE: $W"
grep -nE "customer_whatsapp_links|is_primary|status='ACTIVE'|VERIFIED|wa_verified|whatsapp_identity_id" "$W" | head -40

echo
echo "###### 2) deliver.js delivery: email always + whatsapp when linked ######"
D="$GSZ/lib/deliver.js"
echo "FILE: $D"
echo "--- email guard + whatsapp guard + link lookup ---"
grep -nE "mailer\.(send|configured)|if \(!o|customer_id|customer_whatsapp_links|is_primary|return;|wanotify\.enqueue" "$D" | head -40

echo
echo "###### 3) live counts (how many customers are verified + linked) ######"
node - "$GSZ" <<'NODE' 2>/dev/null || echo "   (db check skipped)"
const R=process.argv[2]; require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const {Pool}=require(R+'/node_modules/pg'); const p=new Pool();
(async()=>{
  const q=async(s)=>{try{return (await p.query(s)).rows[0];}catch(e){return {err:e.message};}};
  console.log('   customers.wa_verified=true :', JSON.stringify(await q("SELECT count(*)::int n FROM customers WHERE wa_verified=true")));
  console.log('   active primary wa links    :', JSON.stringify(await q("SELECT count(*)::int n FROM customer_whatsapp_links WHERE status='ACTIVE' AND is_primary=true")));
  console.log('   verified WITHOUT a link    :', JSON.stringify(await q("SELECT count(*)::int n FROM customers c WHERE c.wa_verified=true AND NOT EXISTS (SELECT 1 FROM customer_whatsapp_links l WHERE l.customer_id=c.id AND l.status='ACTIVE' AND l.is_primary=true)")));
  await p.end();
})().catch(e=>{console.error('   db err',e.message);});
NODE
echo "== END =="
