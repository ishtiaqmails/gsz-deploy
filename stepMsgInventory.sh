#!/usr/bin/env bash
# stepMsgInventory.sh — READ-ONLY. Full inventory of every customer-facing message:
# WhatsApp templates (DB), how wanotify resolves/falls back, and the email templates.
set -u
GSZ=/opt/gsz; cd "$GSZ"

echo "=== template/message tables ==="
node -e "
const R='$GSZ';require(R+'/node_modules/dotenv').config({path:R+'/.env'});
const{Pool}=require(R+'/node_modules/pg');
const p=new Pool({host:process.env.DB_HOST,port:process.env.DB_PORT,database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASS});
(async()=>{
  const t=(await p.query(\"SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND (table_name ILIKE '%template%' OR table_name ILIKE '%wa_%' OR table_name ILIKE '%notif%' OR table_name ILIKE '%message%')\")).rows.map(x=>x.table_name);
  console.log('candidate tables:', t.join(', ')||'(none)');
  for(const tn of t){
    const cols=(await p.query(\"SELECT column_name FROM information_schema.columns WHERE table_name=\$1 ORDER BY ordinal_position\",[tn])).rows.map(x=>x.column_name);
    // only dump tables that look like a template store (have a key + a body/text/content col)
    const hasKey=cols.some(c=>/key|name|slug|event|type/.test(c));
    const bodyCol=cols.find(c=>/body|text|content|message|template|value|html/.test(c));
    if(hasKey && bodyCol){
      const keyCol=cols.find(c=>/template_key|^key$|slug|event|name|type/.test(c))||cols[0];
      const rows=(await p.query('SELECT '+keyCol+' k, '+bodyCol+' b FROM '+tn+' ORDER BY 1').catch(()=>({rows:[]}))).rows;
      console.log('\n--- '+tn+' ('+keyCol+' -> '+bodyCol+', '+rows.length+' rows) ---');
      rows.forEach(r=>{ const b=String(r.b==null?'':r.b); console.log('['+r.k+']\n'+(b.length>600?b.slice(0,600)+' …[+'+(b.length-600)+']':b)+'\n'); });
    } else { console.log('(skip '+tn+' — cols: '+cols.join(',')+')'); }
  }
  await p.end();
})().catch(e=>{console.error(e.message);process.exit(1);});
"

echo ""
echo "=== lib/wanotify.js: how template_key resolves + any built-in default templates ==="
grep -nE "template_key|FROM |templates|default|fallback|render|replace\(|vars\[|\\\$\{" lib/wanotify.js 2>/dev/null | head -30

echo ""
echo "=== lib/emails.js: customer email functions + subjects/headings ==="
[ -f lib/emails.js ] && { echo "lines: $(wc -l < lib/emails.js)"; grep -nE "exports\.|function |subject|<h1|<h2|Hi |Hello|Your order|is ready|Thank|footer|©|&copy;" lib/emails.js | head -40; } || echo "lib/emails.js not found"
