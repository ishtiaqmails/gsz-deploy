'use strict';
/* Premium per-type delivery email.
   - lib/emails.js: add fieldsInner() (login table / IPTV players / MAC list / invite) and render
     it in deliveryEmail from opts.fields; raw delivered_credentials stays as fallback; + warranty.
   - routes/checkout.js emailOrder('delivered'): pass opts.fields (bot_fields, lazy from bot) and
     opts.instructions/opts.warranty from the website admin.
   Anchored (single-line + span), CRLF/indent robust, idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_email.js <ROOT>'); process.exit(1); }

function once(file, name, guard, find, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find); if (i < 0) throw new Error('ANCHOR MISS: ' + name);
  if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(i + find.length));
  console.log('patched: ' + name);
}
function span(file, name, guard, startStr, endStr, replace) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(guard) >= 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(startStr); if (i < 0) throw new Error('SPAN START MISS: ' + name);
  const j = s.indexOf(endStr, i); if (j < 0) throw new Error('SPAN END MISS: ' + name);
  fs.writeFileSync(file, s.slice(0, i) + replace + s.slice(j + endStr.length));
  console.log('patched: ' + name);
}

const EM = path.join(ROOT, 'lib/emails.js');
const CO = path.join(ROOT, 'routes/checkout.js');

const FIELDS_INNER =
"function fieldsInner(f){\n" +
"  var dt=f.delivery_type;\n" +
"  var title = dt==='vendor_invite'?'Check your inbox':(dt==='iptv'?'Your line':(dt==='player_activation'?'Activated':'Your account / login'));\n" +
"  function row(k,v){ return '<tr><td style=\"padding:9px 14px 9px 0;color:#737e9c;border-top:1px solid #eef1f8;font-size:13.5px;vertical-align:top;white-space:nowrap\">'+esc(k)+'</td><td style=\"padding:9px 0;border-top:1px solid #eef1f8;font-size:13.5px;font-family:Consolas,Menlo,monospace;color:#0f1836;word-break:break-all\">'+esc(v)+'</td></tr>'; }\n" +
"  var body='';\n" +
"  if(dt==='vendor_invite'){ var boxes=(f.invite&&f.invite.inboxes)||[]; body=boxes.map(function(b){return row('Inbox',b);}).join(''); }\n" +
"  else if(dt==='player_activation'){ body=(f.activations||[]).map(function(a){ return row(a.mac||'MAC',(a.plan||'')+(a.expiry?(' \\u00b7 exp '+a.expiry):'')); }).join(''); }\n" +
"  else { var details=(f.details||[]).filter(function(d){return d&&d.value&&String(d.label||'').toLowerCase()!=='support';}); body=details.map(function(d){return row(d.label,d.value);}).join(''); }\n" +
"  var out='<div style=\"font-size:12px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:0 0 6px\">'+esc(title)+'</div>';\n" +
"  out+='<table role=\"presentation\" width=\"100%\" cellpadding=\"0\" cellspacing=\"0\" style=\"background:#f7f9fe;border:1px solid #eaf0ff;border-radius:12px;padding:2px 16px\">'+body+'</table>';\n" +
"  if(dt==='iptv'&&(f.players||[]).length){ out+='<div style=\"font-size:12px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:16px 0 8px\">Watch on</div><table role=\"presentation\" cellpadding=\"0\" cellspacing=\"0\"><tr>'+(f.players||[]).map(function(p){return '<td style=\"padding:0 8px 8px 0\">'+btn(p.url||'#',p.platform||'App','#2a7bff')+'</td>';}).join('')+'</tr></table>'; }\n" +
"  if(dt==='vendor_invite'){ out+='<p style=\"margin:10px 0 0;font-size:12.5px;color:#8b93bb\">Open the invite from your inbox \\u2014 check spam/junk too.</p>'; }\n" +
"  else if(f.expiry){ out+='<p style=\"margin:10px 0 0;font-size:12.5px;color:#8b93bb\">Expires: '+esc(f.expiry)+'</p>'; }\n" +
"  return out;\n" +
"}\n\n";

// 1) add fieldsInner before the delivery email function
once(EM, 'emails:fieldsInner', 'function fieldsInner(',
  "// 1) DELIVERY email",
  FIELDS_INNER + "// 1) DELIVERY email");

// 2) render per-type block (fallback to raw) + warranty, replacing the raw-only credentials inner
span(EM, 'emails:delivery-block', 'opts.fields ? fieldsInner(opts.fields)',
  '<div style="font-size:12px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:0 0 8px">Your account / login</div>',
  "Keep these safe. If anything doesn't work, contact us and we'll fix or replace it fast.</p>",
  "${opts.fields ? fieldsInner(opts.fields) : `<div style=\"font-size:12px;font-weight:800;letter-spacing:.4px;text-transform:uppercase;color:#8b93bb;margin:0 0 8px\">Your account / login</div>\n        <div style=\"background:#0f1836;color:#eaf0ff;border-radius:12px;padding:16px;font-family:Consolas,Menlo,monospace;font-size:13.5px;line-height:1.7;white-space:pre-wrap;word-break:break-word\">${esc(o.delivered_credentials || '')}</div>\n        <p style=\"margin:10px 0 0;font-size:12.5px;color:#8b93bb\">Keep these safe. If anything doesn't work, contact us and we'll fix or replace it fast.</p>`}${opts.warranty ? `\n        <div style=\"margin-top:14px;background:#f7f9fe;border:1px solid #eaf0ff;border-radius:12px;padding:12px 16px;font-size:13px;color:#4a5578\"><b style=\"color:#0f1836\">Warranty:</b> ${esc(opts.warranty)}</div>` : ''}");

// 3) checkout emailOrder: feed fields + admin instructions/warranty into the delivery email
once(CO, 'checkout:email-enrich', 'opts.fields = _bf',
  "if (kind === 'delivered') { subject = 'Your order ' + o.order_no + ' is ready'; html = emails.deliveryEmail(o, opts); }",
  "if (kind === 'delivered') {\n      try {\n        const _pr = (await pool.query('SELECT instructions, warranty FROM products WHERE id=$1', [o.product_id])).rows[0] || {};\n        const _plw = (await pool.query('SELECT warranty, delivery_instructions FROM product_plans WHERE product_id=$1 AND label=$2 ORDER BY sort, id LIMIT 1', [o.product_id, o.plan_label])).rows[0] || {};\n        opts.instructions = ((_plw.delivery_instructions || '').trim()) || (_pr.instructions || '');\n        opts.warranty = ((_plw.warranty || '').trim()) || (_pr.warranty || '');\n        let _bf = o.bot_fields; if (typeof _bf === 'string') { try { _bf = JSON.parse(_bf); } catch (e) { _bf = null; } }\n        if ((!_bf || !_bf.delivery_type) && o.source === 'bot' && botapi.configured()) { try { const _st = await botapi.orderStatus(o.order_no); if (_st && _st.fields && _st.fields.delivery_type) _bf = _st.fields; } catch (e) {} }\n        if (_bf && _bf.delivery_type) opts.fields = _bf;\n      } catch (e) {}\n      subject = 'Your order ' + o.order_no + ' is ready'; html = emails.deliveryEmail(o, opts); }");

console.log('EMAIL PATCH OK');
