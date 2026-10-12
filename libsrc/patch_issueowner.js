'use strict';
/* Reroute issue OWNER alerts off the reseller bot onto the Verification Bot.
   Replaces the two botapi.notify(...) owner pings in routes/account.js
   (_clSubmit new request, _clMsg customer reply) with wa_notifications enqueue
   to wa_owner_numbers. Idempotent (guards on the issown- markers). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_issueowner.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

function edit(name, guard, find, repl) {
  if (guard && s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  s = s.slice(0, i) + repl + s.slice(i + find.length);
  console.log('patched: ' + name);
}

// shared owner-enqueue snippet; vars differ per call site
function ownerSnippet(prefix, orderExpr, custExpr, kind, msgExpr, adminUrlExpr, idExpr) {
  return "      try{ var _own=(await pool.query(\"SELECT value FROM wa_settings WHERE key='wa_owner_numbers'\")).rows[0]; var _wn=require('../lib/wanotify')(pool); String((_own&&_own.value)||'').split(',').map(function(x){return x.replace(/\\D/g,'').replace(/^0/,'92');}).filter(Boolean).forEach(function(ph){ _wn.enqueue({ destination_phone:ph, template_key:'whatsapp.issue_owner_alert', vars:{ order_no:" + orderExpr + ", customer:" + custExpr + ", kind:'" + kind + "', message:" + msgExpr + ", admin_url:" + adminUrlExpr + " }, idempotency_key:'" + prefix + "'+" + idExpr + "+'-'+Math.random().toString(36).slice(2,9) }); }); }catch(e){}";
}

/* _clMsg — customer reply alert */
const FIND_MSG = "      try{ const botapi=require('../lib/botapi'); if(botapi.configured&&botapi.configured()){ await botapi.notify({ event:'issue_message', type:'issue_message', from:'customer', order_no:i.order_no, issue_id:id, message:(text||'(screenshot)').slice(0,500) }); } }catch(e){}";
edit('owner alert: customer reply', "issown-reply-", FIND_MSG,
  ownerSnippet('issown-reply-', "i.order_no||''", "(c&&c.email)||'Customer'", 'Customer reply', "(text||'(screenshot)').slice(0,500)", "'https://galaxyzayron.store/admin/issues/'+id", "id"));

/* _clSubmit — new request alert */
const FIND_SUB = "      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'issue', type:'issue', order_no:o.order_no, issue_id:ins.rows[0].id, message:('[Replacement] '+message).slice(0,500) }); } }catch(e){}";
edit('owner alert: new request', "issown-new-", FIND_SUB,
  ownerSnippet('issown-new-', "o.order_no||''", "(c&&c.email)||'Customer'", 'New replacement request', "(message||'').slice(0,500)", "'https://galaxyzayron.store/admin/issues'", "ins.rows[0].id"));

fs.writeFileSync(file, s);
console.log('ISSUE OWNER-ALERT REROUTE OK (now via Verification Bot)');
