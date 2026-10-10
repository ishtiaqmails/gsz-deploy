'use strict';
/* Make /account/tools/pay-methods currency-aware: previously it dropped non-PKR accounts, so
   Binance/USDT was missing. Now every active account shows with its own currency + amount
   (PKR -> "Rs X", USDT/other -> "<CUR> <usd amount>", using the site's USD rate 0.0036).
   Targeted replace of the two pay-methods blocks in routes/account.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_paymethods2.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('currency-aware: PKR + USDT') >= 0) { console.log('skip (already): pay-methods currency-aware'); console.log('PAYMETHODS2 PATCH OK'); process.exit(0); }

const botOld =
"        (accts||[]).forEach(function(a){ const cur=String(a.currency||'PKR').toUpperCase(); if(cur!=='PKR') return; /* region PK: pay in PKR */\n" +
"          methods.push({ key:a.key, name:a.label||a.method||a.name||a.key, pay:fmtPkr(amount), title:a.title||'', account:a.account||'', details:a.details||'', instructions:a.instructions||'' }); });";
const botNew =
"        const _usd=function(p){ return (Math.round(Number(p||0)*0.0036*100)/100); };\n" +
"        (accts||[]).forEach(function(a){ const cur=String(a.currency||'PKR').toUpperCase(); /* currency-aware: PKR + USDT/crypto */\n" +
"          const pay=(cur==='PKR')?fmtPkr(amount):(cur+' '+_usd(amount));\n" +
"          methods.push({ key:a.key, name:a.label||a.method||a.name||a.key, currency:cur, pay:pay, title:a.title||'', account:a.account||'', details:a.details||'', instructions:a.instructions||'' }); });";

const fbOld =
"    if(!methods.length){ try{ const rows=(await pool.query(\"SELECT key, name, details, instructions, currency FROM payment_methods WHERE COALESCE(currency,'PKR')='PKR' ORDER BY id LIMIT 12\")).rows; methods=rows.map(function(m){ return { key:m.key, name:m.name, pay:fmtPkr(amount), title:'', account:'', details:m.details||'', instructions:m.instructions||'' }; }); }catch(e){} }";
const fbNew =
"    if(!methods.length){ try{ const _usd2=function(p){ return (Math.round(Number(p||0)*0.0036*100)/100); }; const rows=(await pool.query(\"SELECT key, name, details, instructions, currency FROM payment_methods WHERE active ORDER BY sort,id LIMIT 12\")).rows; methods=rows.map(function(m){ const cur=String(m.currency||'PKR').toUpperCase(); return { key:m.key, name:m.name, currency:cur, pay:(cur==='PKR'?fmtPkr(amount):(cur+' '+_usd2(amount))), title:'', account:'', details:m.details||'', instructions:m.instructions||'' }; }); }catch(e){} }";

if (s.indexOf(botOld) < 0) throw new Error('ANCHOR MISS: pay-methods bot loop not in expected form');
s = s.replace(botOld, botNew);
if (s.indexOf(fbOld) < 0) throw new Error('ANCHOR MISS: pay-methods fallback query not in expected form');
s = s.replace(fbOld, fbNew);

fs.writeFileSync(file, s);
console.log('patched: pay-methods currency-aware (PKR + USDT/Binance)');
console.log('PAYMETHODS2 PATCH OK');
