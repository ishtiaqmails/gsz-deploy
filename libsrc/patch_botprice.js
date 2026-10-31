'use strict';
/* BOTPRICE_v1 — add owner `price <product> [plan] [country]` to ownerCommand() in whatsapp.js.
   Reuses the Stage-1 engine; mirrors the /api/owner/price logic but replies as WhatsApp text.
   Only owner numbers (wa_owner_numbers) reach ownerCommand, so no extra gating needed.
   2 edits. Idempotent (done-marker-first); split/join; throws on a miss so the step restores. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';
const F = 'routes/whatsapp.js';

// Regex-free, backslash-free branch (raw UTF-8 symbols; newline via fromCharCode). Inserted
// among the sibling `if` blocks inside ownerCommand's try.
const PRICE_BRANCH =
`if (t.toLowerCase()==='price' || t.toLowerCase().indexOf('price ')===0) { const rest=t.slice(5).trim(); const NL=String.fromCharCode(10); if(!rest) return 'Usage: price <product> [plan] [country]'+NL+'e.g. price netflix 1month GB'; let parts=rest.split(' ').filter(Boolean); let country='US'; const lt=parts[parts.length-1]; if(parts.length>=2 && lt.length===2 && isNaN(Number(lt))) country=parts.pop().toUpperCase(); const product=parts.shift()||''; const planQ=parts.join(' '); const prow=(await pool.query("SELECT id,name FROM products WHERE slug=$1 OR name ILIKE $2 OR slug ILIKE $2 ORDER BY (slug=$1) DESC, id LIMIT 1",[product.toLowerCase(),'%'+product+'%'])).rows[0]; if(!prow) return 'No product matching "'+product+'".'; let plans=(await pool.query("SELECT label,price_pkr,price_usd FROM product_plans WHERE product_id=$1 ORDER BY sort,id",[prow.id])).rows; if(planQ){ const pq=planQ.toLowerCase().split(' ').join(''); plans=plans.filter(function(p){return String(p.label||'').toLowerCase().split(' ').join('').indexOf(pq)>=0;}); } if(!plans.length) return 'No plan matching "'+planQ+'" in '+prow.name+'.'; const pricing=require('../lib/gsz_pricing'); let buf=0; try{ const _b=(await pool.query("SELECT value FROM wa_settings WHERE key='price_buffer_pct'")).rows[0]; buf=_b?(parseFloat(_b.value)||0):0; }catch(e){} const _R=await pricing.rates(false); const upp=(_R&&_R.PKR)?(1/_R.PKR):0; const L=['💱 '+prow.name+' — '+country+(buf?(' (buffer '+buf+'%)'):'')]; for(const pl of plans.slice(0,12)){ const pkr=Number(pl.price_pkr||0); const usdBase=Number(pl.price_usd||0)>0?Number(pl.price_usd):+(pkr*upp).toFixed(2); let shown,loc=''; if(country==='PK'){ shown='Rs '+Math.round(pkr).toLocaleString('en-US'); } else { shown='$'+usdBase.toFixed(2); try{ const q2=await pricing.resolve({price_pkr:pkr,price_usd:Number(pl.price_usd||0)},country,{bufferPct:buf}); if(q2&&q2.currency&&q2.currency!=='USD') loc=' (local: '+q2.display+')'; }catch(e){} } L.push(''); L.push('• '+pl.label); L.push('   Sees: '+shown+loc); L.push('   Pays: Rs '+Math.round(pkr).toLocaleString('en-US')+' (bank) or $'+usdBase.toFixed(2)+' (Binance)'); if(Number(pl.price_usd||0)<=0) L.push('   ⚠ no $ set — live conversion'); } return L.join(NL); }`;

const edits = [
  // 1) add a `price` bullet to the owner help menu
  { old: "'\\u2022 addstock <planId> then one unit per line', '',",
    neu: "'\\u2022 addstock <planId> then one unit per line', '• price <product> [plan] [country] — what a country sees', '',",
    done: "• price <product> [plan] [country] — what a country sees" },

  // 2) insert the price branch just before the try's catch
  { old: "    } catch (e) { return 'Command error: ' + e.message; }",
    neu: "      " + PRICE_BRANCH + "\n    } catch (e) { return 'Command error: ' + e.message; }",
    done: "t.toLowerCase().indexOf('price ')" },
];

let s = fs.readFileSync(path.join(ROOT, F), 'utf8');
let applied = 0, skipped = 0;
for (const e of edits) {
  if (s.indexOf(e.done) >= 0) { skipped++; continue; }
  const n = s.split(e.old).length - 1;
  if (n === 0) throw new Error('ANCHOR MISSING in ' + F + ': ' + e.old.slice(0, 55));
  if (n !== 1) throw new Error('anchor not unique (' + n + ') in ' + F + ': ' + e.old.slice(0, 40));
  s = s.split(e.old).join(e.neu); applied++;
}
fs.writeFileSync(path.join(ROOT, F), s);
console.log('BOTPRICE_v1 applied=' + applied + ' skipped=' + skipped);
