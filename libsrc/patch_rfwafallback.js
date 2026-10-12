'use strict';
/* Renew subscription check: the Hub's _rfWa(c) resolved the customer's WhatsApp ONLY from the
   customer_whatsapp_links/whatsapp_identities tables. Customers who verified a number the older
   way have customers.wa_number set but no active identity link, so _rfWa returned '' and
   gsz-api could not match their order -> the Hub wrongly showed "not renewable" (amember + iptv).
   Fix: prefer the customer's own customers.wa_number (what the order was placed with), then fall
   back to the identity-link number. routes/account.js. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_rfwafallback.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/*rfWaFallback*/') >= 0) { console.log('skip (already): _rfWa fallback'); console.log('RFWA PATCH OK'); process.exit(0); }

const FIND = "  async function _rfWa(c){ try{ const L=(await pool.query(\"SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id])).rows[0]; return (L&&L.current_phone_e164)?String(L.current_phone_e164).replace(/[^0-9]/g,''):''; }catch(e){ return ''; } }";

const REPL = "  async function _rfWa(c){ /*rfWaFallback*/ try{ const r=(await pool.query(\"SELECT wa_number FROM customers WHERE id=$1\",[c.id])).rows[0]; const v=(r&&r.wa_number)?String(r.wa_number).replace(/[^0-9]/g,''):''; if(v) return v; }catch(e){} try{ const L=(await pool.query(\"SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1\",[c.id])).rows[0]; return (L&&L.current_phone_e164)?String(L.current_phone_e164).replace(/[^0-9]/g,''):''; }catch(e){ return ''; } }";

const i = s.indexOf(FIND);
if (i < 0) throw new Error('ANCHOR MISS: _rfWa function not found in account.js');
if (s.indexOf(FIND, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: _rfWa');
s = s.slice(0, i) + REPL + s.slice(i + FIND.length);
fs.writeFileSync(file, s);
console.log('patched: _rfWa now prefers customers.wa_number, falls back to identity link');
console.log('RFWA PATCH OK');
