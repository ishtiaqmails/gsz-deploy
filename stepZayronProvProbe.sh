#!/usr/bin/env bash
# stepZayronProvProbe — READ-ONLY. Confirms zayron's panels/plans map to gsz-api products, so the
# provisioning rewrite (submit via gsz-api instead of the dead direct-DB link) can't fail on a
# mismatch. Lists gsz-api iptv products (sku/panel/plans) and zayron's servers (reseller_pid) + plan
# labels, and shows which servers resolve to a sku. Changes nothing.
set -e
cd /opt/zayron
node <<'NODE'
const https=require('https'),http=require('http'),{URL}=require('url');
try{require('fs').readFileSync('/opt/zayron/.env','utf8').split('\n').forEach(function(l){var m=l.match(/^(GSZ_BOT_API_(URL|KEY))=(.*)$/);if(m)process.env[m[1]]=m[3].trim();});}catch(e){}
const { pool } = require('./db');
function get(path){return new Promise(function(res,rej){try{const u=new URL(process.env.GSZ_BOT_API_URL.replace(/\/+$/,'')+path);const lib=u.protocol==='http:'?http:https;const r=lib.request({method:'GET',hostname:u.hostname,port:u.port||(u.protocol==='http:'?80:443),path:u.pathname,headers:{'X-API-Key':process.env.GSZ_BOT_API_KEY,'Accept':'application/json'}},function(rs){let b='';rs.on('data',d=>b+=d);rs.on('end',function(){try{res(JSON.parse(b))}catch(e){rej(e)}});});r.on('error',rej);r.setTimeout(8000,function(){r.destroy(new Error('timeout'))});r.end();}catch(e){rej(e)}});}
(async()=>{
  try{
    const prod = await get('/api/products').catch(e=>({error:e.message}));
    const iptv = ((prod&&prod.products)||[]).filter(p=>p.delivery_type==='iptv');
    console.log('=== gsz-api IPTV products ===');
    iptv.forEach(p=>console.log('  sku='+p.sku+' | name="'+(p.name||'')+'" | plans=['+(p.plans||[]).map(x=>x.plan_key+':'+x.label).join(' , ')+']'));
    if(prod&&prod.error) console.log('  (products error: '+prod.error+')');

    // zayron servers + their panel ids
    let cols=[];
    try{ cols=(await pool.query("SELECT column_name FROM information_schema.columns WHERE table_name='servers'")).rows.map(r=>r.column_name);}catch(e){}
    console.log('\n=== zayron servers table cols ===\n  '+cols.join(', '));
    const pidCol = cols.indexOf('reseller_pid')>=0 ? 'reseller_pid' : (cols.indexOf('panel_id')>=0?'panel_id':null);
    const nameCol = cols.indexOf('n')>=0?'n':(cols.indexOf('name')>=0?'name':cols[0]);
    if(pidCol){
      const sv=(await pool.query('SELECT id, '+pidCol+' AS pid, '+nameCol+' AS nm FROM servers ORDER BY id')).rows;
      console.log('\n=== zayron servers -> sku match ===');
      sv.forEach(s=>{const m=iptv.find(p=>String(p.iptv_panel_id)===String(s.pid));console.log('  server#'+s.id+' "'+(s.nm||'')+'" panel='+s.pid+' => '+(m?('MATCH sku='+m.sku):'NO MATCH'));});
    } else { console.log('\n(no reseller_pid/panel_id column found on servers)'); }

    // zayron plan labels vs product plan labels
    const pl=(await pool.query("SELECT DISTINCT plan_label FROM orders WHERE plan_label IS NOT NULL AND plan_label<>'' ORDER BY plan_label").catch(()=>({rows:[]}))).rows;
    console.log('\n=== zayron plan_labels seen in orders ===\n  '+(pl.map(x=>x.plan_label).join(' | ')||'(none)'));
    const prodLabels=[...new Set([].concat(...iptv.map(p=>(p.plans||[]).map(x=>x.label))))];
    console.log('=== gsz-api product plan labels ===\n  '+(prodLabels.join(' | ')||'(none)'));
    console.log('\nPROBE DONE — nothing changed.');
  }catch(e){ console.log('PROBE ERR', e.message); }
  process.exit(0);
})();
NODE
