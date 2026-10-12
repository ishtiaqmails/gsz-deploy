'use strict';
/* GSZ checkout: support the Hub "Renew IPTV Subscription" pay step — renew a pasted line
   (not an owned order). Mirrors the existing renew_of path:
     - POST /checkout accepts a `renew_line` JSON field -> stored in fields.renew_line
     - fulfill(): if fields.renew_line, call botapi.renew() with the LINE (username, raw,
       sku, plan_key, version, whatsapp) -> gsz-api startRenewLine (no order_no)
     - pollOnce(): poll renewStatus for renew_line just like renew_of
   The chosen GSZ plan supplies amount + bot_sku + bot_plan_key (the order is a normal bot
   order). Idempotent; aborts if an anchor moved (step auto-restores). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_iptvrenew.js <ROOT>'); process.exit(1); }

function patch(rel, edits) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const e of edits) {
    if (s.indexOf(e.guard) >= 0) { console.log('skip (already): ' + rel + ' :: ' + e.name); continue; }
    const i = s.indexOf(e.find);
    if (i < 0) throw new Error('ANCHOR MISS: ' + rel + ' :: ' + e.name);
    if (s.indexOf(e.find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + e.name);
    s = s.slice(0, i) + e.repl + s.slice(i + e.find.length);
    console.log('patched: ' + rel + ' :: ' + e.name);
  }
  fs.writeFileSync(file, s);
}

const PARSE =
"      const renewOf = String(b.renew || '').trim().slice(0, 32);\n" +
"      let renewLine = null;\n" +
"      try {\n" +
"        if (b.renew_line) {\n" +
"          const _rl = (typeof b.renew_line === 'string') ? JSON.parse(b.renew_line) : b.renew_line;\n" +
"          if (_rl && _rl.username) renewLine = { username: String(_rl.username).slice(0,120), raw: String(_rl.raw||'').slice(0,4000), version: String(_rl.version||'family').slice(0,24), sku: String(_rl.sku||'').slice(0,40) };\n" +
"        }\n" +
"      } catch (e) {}\n";

const RENEW_LINE_BRANCH =
"      if (_ofR.renew_line) {\n" +
"        try {\n" +
"          const _rl = _ofR.renew_line;\n" +
"          const rr = await botapi.renew({\n" +
"            renewal_id: 'ren-' + o.order_no,\n" +
"            sku: o.bot_sku,\n" +
"            username: _rl.username,\n" +
"            raw: _rl.raw || '',\n" +
"            plan_key: o.bot_plan_key,\n" +
"            version: _rl.version || 'family',\n" +
"            whatsapp: String(o.whatsapp || '').replace(/[^0-9]/g, '')\n" +
"          });\n" +
"          if (rr && rr.ok === false) {\n" +
"            await pool.query(\"UPDATE orders SET status='failed', claim_result=$1 WHERE id=$2\", [('renew_' + (rr.reason || 'err')).slice(0, 80), o.id]);\n" +
"            return;\n" +
"          }\n" +
"          await pool.query(\"UPDATE orders SET status='delivering', bot_order_id=$1 WHERE id=$2\", [String((rr && rr.request_id) || ('ren-' + o.order_no)), o.id]);\n" +
"          await pollOnce(o.order_no);\n" +
"        } catch (e) {\n" +
"          await pool.query('UPDATE orders SET claim_result=$1 WHERE id=$2', [('renew_err:' + e.message).slice(0, 80), o.id]);\n" +
"        }\n" +
"        return;\n" +
"      }\n";

patch('routes/checkout.js', [
  { name: 'parse-renew-line', guard: 'let renewLine = null;',
    find: "      const renewOf = String(b.renew || '').trim().slice(0, 32);\n",
    repl: PARSE },
  { name: 'store-renew-line', guard: 'fields.renew_line = renewLine',
    find: "      if (renewTarget) fields.renew_of = renewTarget;",
    repl: "      if (renewTarget) fields.renew_of = renewTarget;\n      if (renewLine) fields.renew_line = renewLine;" },
  { name: 'fulfill-renew-line', guard: 'if (_ofR.renew_line)',
    find: "      const _ofR = (o.fields && typeof o.fields === 'object') ? o.fields : {};\n      if (_ofR.renew_of) {",
    repl: "      const _ofR = (o.fields && typeof o.fields === 'object') ? o.fields : {};\n" + RENEW_LINE_BRANCH + "      if (_ofR.renew_of) {" },
  { name: 'poll-renew-line', guard: 'if (_ofP.renew_of || _ofP.renew_line)',
    find: "      if (_ofP.renew_of) {",
    repl: "      if (_ofP.renew_of || _ofP.renew_line) {" }
]);

console.log('IPTV RENEW (checkout) PATCH OK');
