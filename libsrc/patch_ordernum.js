'use strict';
/* Reset-proof order_no:
   1) Generate order_no from a dedicated, independent sequence (order_no_seq) instead of
      'GSZ-'+(1000+id). The orders serial id rewinds on TRUNCATE ... RESTART IDENTITY; a
      standalone sequence does not, so order_no can never collide with the bot again.
   2) On the single-order bot path, handle the bot's new {ok:false,error:"order_no_collision"}
      by re-issuing a fresh order_no and retrying once; surface any other submit failure
      instead of silently marking the order 'delivering'. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_ordernum.js <ROOT>'); process.exit(1); }
function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    if (e.all) {
      if (s.indexOf(e.find) < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
      const n = s.split(e.find).length - 1;
      s = s.split(e.find).join(e.replace);
      console.log('patched x' + n + ': ' + rel + ' :: ' + e.name);
    } else {
      const first = s.indexOf(e.find);
      if (first < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
      if (s.indexOf(e.find, first + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
      s = s.slice(0, first) + e.replace + s.slice(first + e.find.length);
      console.log('patched: ' + rel + ' :: ' + e.name);
    }
  }
  fs.writeFileSync(file, s);
}

patch('routes/checkout.js', [
  {
    name: 'order_no-from-sequence', all: true,
    guard: "nextval('order_no_seq')",
    find: "const order_no = 'GSZ-' + (1000 + id);",
    replace: "const order_no = 'GSZ-' + ((await pool.query(\"SELECT nextval('order_no_seq') AS n\")).rows[0].n);"
  },
  {
    name: 'single-collision-retry',
    guard: "order_no_collision",
    find: "        const sr = await botapi.submitOrder(payload);\n"
      + "        await pool.query(\"UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2\", [String((sr && sr.order_id) || ''), o.id]);\n"
      + "        await pollOnce(o.order_no);\n",
    replace: "        let sr = await botapi.submitOrder(payload);\n"
      + "        if (sr && sr.ok === false && String(sr.error || '') === 'order_no_collision') {\n"
      + "          const _nn = 'GSZ-' + ((await pool.query(\"SELECT nextval('order_no_seq') AS n\")).rows[0].n);\n"
      + "          await pool.query('UPDATE orders SET order_no=$1 WHERE id=$2', [_nn, o.id]);\n"
      + "          o.order_no = _nn; payload.ref = _nn; payload.orderNo = _nn;\n"
      + "          sr = await botapi.submitOrder(payload);\n"
      + "        }\n"
      + "        if (sr && sr.ok === false) {\n"
      + "          await pool.query(\"UPDATE orders SET status='failed', claim_result=$1 WHERE id=$2\", [('submit_' + String(sr.error || 'err')).slice(0, 80), o.id]);\n"
      + "          return;\n"
      + "        }\n"
      + "        await pool.query(\"UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2\", [String((sr && sr.order_id) || ''), o.id]);\n"
      + "        await pollOnce(o.order_no);\n"
  }
]);
console.log('ORDERNUM PATCH OK');
