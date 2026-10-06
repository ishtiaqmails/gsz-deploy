#!/usr/bin/env bash
# wadiag — READ-ONLY. Shows exactly what the bot captured for the most recent
# WhatsApp verification: the identity, its raw/normalized aliases, the linked
# customer (and the number they typed at signup), and the session. Changes nothing.
set -euo pipefail
cd /opt/gsz
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
(async()=>{
  const idn = (await p.query('SELECT * FROM whatsapp_identities ORDER BY id DESC LIMIT 1')).rows[0];
  if(!idn){ console.log('No whatsapp_identities yet.'); return p.end(); }
  console.log('=== latest identity #'+idn.id+' ===');
  console.log('  canonical_lid       :', idn.canonical_lid);
  console.log('  current_phone_e164  :', idn.current_phone_e164);
  console.log('  current_phone_verif :', idn.current_phone_verified);
  console.log('  phone_source        :', idn.phone_source);
  console.log('  status              :', idn.status);
  const al = (await p.query('SELECT identifier_type, identifier_value, normalized_value FROM whatsapp_identity_aliases WHERE whatsapp_identity_id=$1 ORDER BY id',[idn.id])).rows;
  console.log('=== aliases (what WhatsApp actually sent) ===');
  al.forEach(a=>console.log('  ['+a.identifier_type+'] raw="'+a.identifier_value+'"  norm="'+a.normalized_value+'"'));
  const lk = (await p.query("SELECT l.customer_id, l.status, l.verified_at, c.email, c.wa_number AS signup_wa, c.ref_code FROM customer_whatsapp_links l JOIN customers c ON c.id=l.customer_id WHERE l.whatsapp_identity_id=$1 ORDER BY l.id DESC LIMIT 1",[idn.id])).rows[0];
  console.log('=== linked customer ===');
  if(lk){ console.log('  customer_id         :', lk.customer_id);
    console.log('  email               :', lk.email);
    console.log('  number typed @signup:', lk.signup_wa);
    console.log('  ref_code            :', lk.ref_code);
    console.log('  link status         :', lk.status, '| verified_at', lk.verified_at); }
  else console.log('  (no active link)');
  const s = (await p.query("SELECT id, display_code, status, completed_at FROM whatsapp_verification_sessions ORDER BY id DESC LIMIT 1")).rows[0];
  console.log('=== latest verification session ===');
  if(s) console.log('  #'+s.id, '| code', s.display_code, '| status', s.status, '| completed', s.completed_at);
  await p.end();
})().catch(e=>{ console.error('diag error:', e.message); p.end(); });
NODE
