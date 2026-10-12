'use strict';
/* Customer side of the issue chat (routes/account.js):
   1) new claims seed their first thread message (issue_messages).
   2) /account/tools/claims returns each issue's full thread (messages[]).
   3) new routes: POST /account/tools/issue/:id/message (customer reply, text+screenshot),
      GET /account/tools/issue-msg-file/:mid (serve a thread screenshot — own issues only).
   Idempotent; aborts if an anchor moved. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_issuethread.js <ROOT>'); process.exit(1); }
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

/* 1) seed first thread message on new claim (before the owner-alert notify) */
const NOTIFY_LINE = "      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'issue', type:'issue', order_no:o.order_no, issue_id:ins.rows[0].id, message:('[Replacement] '+message).slice(0,500) }); } }catch(e){}";
const SEED = "      try{ await pool.query(\"INSERT INTO issue_messages(issue_id,sender,body,screenshot,seen_by_admin,seen_by_customer) VALUES($1,'customer',$2,$3,false,true)\",[ins.rows[0].id, message, shot]); }catch(e){}\n";
edit('seed first message', "INSERT INTO issue_messages(issue_id,sender,body,screenshot,seen_by_admin,seen_by_customer) VALUES($1,'customer',$2,$3,false,true)\",[ins.rows[0].id", NOTIFY_LINE, SEED + NOTIFY_LINE);

/* 2a) fetch thread messages for the listed issues */
const ROWS_LINE = "    try{ rows=(await pool.query(\"SELECT i.id, i.order_no, i.message, i.status, i.decision, i.admin_response, i.admin_screenshot, i.replacement_credentials, i.created_at, i.resolved_at, o.product_name FROM order_issues i LEFT JOIN orders o ON o.id=i.order_id WHERE i.customer_id=$1 ORDER BY i.id DESC LIMIT 30\",[c.id])).rows; }catch(e){}";
const MSGS_FETCH = "\n    var byId={}; try{ var _ids=rows.map(function(r){return r.id;}); if(_ids.length){ (await pool.query(\"SELECT id, issue_id, sender, body, screenshot, created_at FROM issue_messages WHERE issue_id = ANY($1::int[]) ORDER BY id ASC\",[_ids])).rows.forEach(function(m){ (byId[m.issue_id]=byId[m.issue_id]||[]).push({ id:m.id, sender:m.sender, body:m.body||'', has_shot:!!m.screenshot, created_at:m.created_at }); }); } }catch(e){}";
edit('messages fetch', "var byId={}; try{ var _ids=rows.map", ROWS_LINE, ROWS_LINE + MSGS_FETCH);

/* 2b) include messages in each claim */
edit('messages in claim', "resolved_at:i.resolved_at, messages:",
  "resolved_at:i.resolved_at }; }) });",
  "resolved_at:i.resolved_at, messages:(byId[i.id]||[]) }; }) });");

/* 3) customer reply + message-file routes (before the GET CODE section) */
const GETCODE = "  // ---- GET CODE (self-aware retrieve capabilities) ----";
const NEWROUTES =
  "  // ---- customer reply into an issue thread (two-way) ----\n" +
  "  router.post('/account/tools/issue/:id/message', requireLogin, function(req,res){ _clMul.single('shot')(req,res,function(){ _clMsg(req,res); }); });\n" +
  "  async function _clMsg(req,res){\n" +
  "    const c=req.session.customer; const id=parseInt(req.params.id,10)||0;\n" +
  "    const text=String((req.body&&req.body.body)||'').trim().slice(0,2000);\n" +
  "    const shot=(req.file&&req.file.filename)?req.file.filename:null;\n" +
  "    if(!id || (!text && !shot)) return res.json({ ok:false, error:'Write a message first.' });\n" +
  "    try{\n" +
  "      const i=(await pool.query(\"SELECT id, order_no, status FROM order_issues WHERE id=$1 AND customer_id=$2 LIMIT 1\",[id,c.id])).rows[0];\n" +
  "      if(!i) return res.json({ ok:false, error:'Not found.' });\n" +
  "      await pool.query(\"INSERT INTO issue_messages(issue_id,sender,body,screenshot,seen_by_admin,seen_by_customer) VALUES($1,'customer',$2,$3,false,true)\",[id,text||null,shot]);\n" +
  "      if(String(i.status||'').toLowerCase()!=='open'){ try{ await pool.query(\"UPDATE order_issues SET status='open', resolved_at=NULL WHERE id=$1\",[id]); }catch(e){} }\n" +
  "      try{ const botapi=require('../lib/botapi'); if(botapi.configured&&botapi.configured()){ await botapi.notify({ event:'issue_message', type:'issue_message', from:'customer', order_no:i.order_no, issue_id:id, message:(text||'(screenshot)').slice(0,500) }); } }catch(e){}\n" +
  "      res.json({ ok:true });\n" +
  "    }catch(e){ res.json({ ok:false, error:'Could not send. Please try again.' }); }\n" +
  "  }\n" +
  "  router.get('/account/tools/issue-msg-file/:mid', requireLogin, async (req,res) => {\n" +
  "    const c=req.session.customer; const mid=parseInt(req.params.mid,10)||0;\n" +
  "    try{ const m=(await pool.query(\"SELECT m.screenshot FROM issue_messages m JOIN order_issues i ON i.id=m.issue_id WHERE m.id=$1 AND i.customer_id=$2 LIMIT 1\",[mid,c.id])).rows[0]; if(!m||!m.screenshot) return res.status(404).end(); return res.sendFile(_clP.join(_clDir, _clP.basename(m.screenshot))); }catch(e){ res.status(404).end(); }\n" +
  "  });\n\n";
edit('customer reply routes', "/account/tools/issue/:id/message", GETCODE, NEWROUTES + GETCODE);

fs.writeFileSync(file, s);
console.log('ISSUE THREAD (customer) PATCH OK');
