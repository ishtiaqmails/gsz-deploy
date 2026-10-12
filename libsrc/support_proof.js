'use strict';
/* Proof harness: builds the Support Bot knowledge base from the REAL database and runs real
   customer questions through the answer engine — so we can see Stage 1 (KB) and Stage 2
   (answers) actually working on live data before any UI is wired. Read-only. */
const path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node support_proof.js <ROOT>'); process.exit(1); }
require(path.join(ROOT, 'node_modules/dotenv')).config({ path: path.join(ROOT, '.env') });
const { Pool } = require(path.join(ROOT, 'node_modules/pg'));
const kb = require(path.join(ROOT, 'lib/supportkb'));
const bot = require(path.join(ROOT, 'lib/supportbot'));
const pool = new Pool({ host: process.env.DB_HOST, port: process.env.DB_PORT, database: process.env.DB_NAME, user: process.env.DB_USER, password: process.env.DB_PASS });

(async () => {
  const k = await kb.get(pool, { force: true });
  console.log('KB indexed:', JSON.stringify(k.counts));
  console.log('site:', k.site.name, '| whatsapp:', k.site.wa_number || '(none)');
  console.log('categories:', k.categories.map(c => c.name + '(' + c.slug + ')').join(', '));
  const sample = k.products.find(p => /opplex/i.test(p.name)) || k.products[0];
  if (sample) {
    console.log('\nSample product:', sample.name, '->', sample.url);
    console.log('  from', sample.priceFrom, '| plans', sample.plans.length, '| faqs', sample.faqs.length, '| keywords', sample.keywords.length);
    console.log('  plans:', sample.plans.map(x => x.label + '=' + x.price_pkr).join(', '));
  }

  const qs = [
    'how much is opplex tv', 'opplex plans', 'recommend a good iptv', 'cheapest vpn',
    'do you have netflix', 'how fast is delivery for opplex', 'is canva available',
    'any offers today', 'i want to talk to a human', 'renew my subscription'
  ];
  console.log('\n=== real Q&A (grounded in the live catalog) ===');
  for (const q of qs) {
    const a = bot.answer(k, q, {});
    console.log('\nQ: ' + q);
    console.log('  [' + a.intent + ']' + (a.handoff ? ' handoff' : '') + (a.needsAction ? ' action:' + a.needsAction : ''));
    console.log('  ' + a.text.replace(/\n/g, '\n  '));
    if (a.products && a.products.length) console.log('  -> ' + a.products.map(x => x.name + ' ' + x.url).join(' | '));
  }
  console.log('\nSUPPORTPROOF OK');
  await pool.end();
})().catch(e => { console.error('PROOF ERR ' + e.message); process.exit(1); });
