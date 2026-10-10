'use strict';
/* Trials in the Hub (added to routes/account.js):
   - GET  /account/tools/trials            -> customer's trials: creds, expiry, days/hours left, status,
                                              extendable (within 2 days of claim, not yet extended), converted-excluded
   - POST /account/tools/trials/:id/extend -> asks the bot to extend +2 days (botapi.extendTrial);
                                              on success bumps expiry; if the bot hook isn't ready, records the
                                              request + notifies, so the customer always gets a positive reply
   - GET  /account/tools/trials/:id/buy    -> resolves the paid IPTV product matching the trial's service (Convert) */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_trials.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

if (s.indexOf('/account/tools/trials') >= 0) { console.log('skip (already): trials endpoints present'); console.log('TRIALS PATCH OK'); process.exit(0); }

const ROUTES =
"  // ---- TRIALS (Hub) ----\n" +
"  router.get('/account/tools/trials', requireLogin, async (req, res) => {\n" +
"    const c = req.session.customer; let rows=[];\n" +
"    try{ rows=(await pool.query(\"SELECT id, trial_type, server_name, status, credentials, expires_at, duration_hours, claimed_at, metadata FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 25\",[c.id])).rows; }catch(e){}\n" +
"    const now=Date.now();\n" +
"    res.json({ ok:true, trials: rows.map(function(t){\n" +
"      const md=t.metadata||{}; if(md.gsz_converted||md.converted) return null;\n" +
"      const exp=t.expires_at?new Date(t.expires_at).getTime():null;\n" +
"      const claimed=t.claimed_at?new Date(t.claimed_at).getTime():null;\n" +
"      const msLeft=exp!=null?(exp-now):null;\n" +
"      const st=String(t.status||'').toLowerCase();\n" +
"      const done=['active','delivered','done','completed'].indexOf(st)>=0;\n" +
"      const extended=!!md.gsz_extended, requested=!!md.gsz_extend_requested;\n" +
"      const windowOpen = claimed ? (now < claimed + 2*86400000) : false;\n" +
"      return { id:t.id, server:t.server_name||t.trial_type||'IPTV trial', credentials: done?(t.credentials||''):'',\n" +
"        status:t.status, pending: st==='pending', claimed:t.claimed_at, expires:t.expires_at,\n" +
"        active: exp!=null?(exp>now):true, days_left: exp!=null?Math.floor(msLeft/86400000):null, hours_left: exp!=null?Math.ceil(msLeft/3600000):null,\n" +
"        extendable: (!extended && !requested && windowOpen), extended:extended, extend_requested:requested };\n" +
"    }).filter(Boolean) });\n" +
"  });\n" +
"  router.post('/account/tools/trials/:id/extend', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const id=parseInt(req.params.id,10)||0;\n" +
"    try{\n" +
"      const t=(await pool.query(\"SELECT id, bot_ref, server_name, trial_type, status, claimed_at, metadata FROM trial_claims WHERE id=$1 AND customer_id=$2 LIMIT 1\",[id,c.id])).rows[0];\n" +
"      if(!t) return res.json({ ok:false, error:'not_found' });\n" +
"      const md=t.metadata||{}; if(md.gsz_extended) return res.json({ ok:false, error:'already' });\n" +
"      const claimed=t.claimed_at?new Date(t.claimed_at).getTime():0;\n" +
"      if(!(claimed && Date.now() < claimed + 2*86400000)) return res.json({ ok:false, error:'window_closed' });\n" +
"      let ok=false;\n" +
"      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured() && botapi.extendTrial){ const r=await botapi.extendTrial({ rid:t.bot_ref||null, bot_ref:t.bot_ref||null, sku:t.trial_type||null, server:t.server_name||null, days:2 }); ok=!!(r && (r.ok===true || r.status==='ok' || r.extended===true)); } }catch(e){}\n" +
"      if(ok){\n" +
"        await pool.query(\"UPDATE trial_claims SET expires_at = COALESCE(expires_at, now()) + interval '2 days', status='active', metadata = COALESCE(metadata,'{}'::jsonb) || '{\\\"gsz_extended\\\":true}'::jsonb WHERE id=$1\",[id]);\n" +
"        const row=(await pool.query(\"SELECT expires_at FROM trial_claims WHERE id=$1\",[id])).rows[0];\n" +
"        return res.json({ ok:true, extended:true, expires:row?row.expires_at:null });\n" +
"      }\n" +
"      await pool.query(\"UPDATE trial_claims SET metadata = COALESCE(metadata,'{}'::jsonb) || jsonb_build_object('gsz_extend_requested', to_jsonb(now())) WHERE id=$1\",[id]);\n" +
"      try{ const botapi=require('../lib/botapi'); if(botapi.configured && botapi.configured()){ await botapi.notify({ event:'trial_extend', type:'trial_extend', trial_id:id, ref:t.bot_ref||'', server:t.server_name||'', days:2 }); } }catch(e){}\n" +
"      return res.json({ ok:true, extended:false, requested:true });\n" +
"    }catch(e){ res.json({ ok:false, error:'error' }); }\n" +
"  });\n" +
"  router.get('/account/tools/trials/:id/buy', requireLogin, async (req, res) => {\n" +
"    const c=req.session.customer; const id=parseInt(req.params.id,10)||0;\n" +
"    try{\n" +
"      const t=(await pool.query(\"SELECT server_name, trial_type FROM trial_claims WHERE id=$1 AND customer_id=$2 LIMIT 1\",[id,c.id])).rows[0];\n" +
"      if(!t) return res.json({ ok:false });\n" +
"      const name=String(t.server_name||''); const first=(name.split(/[\\/|,(]/)[0]||'').trim(); const w1=(first.split(/\\s+/)[0]||first);\n" +
"      const prow=(await pool.query(\"SELECT p.slug, p.name FROM products p JOIN categories cat ON cat.id=p.category_id WHERE cat.slug='iptv' AND p.active AND NOT p.hidden AND (p.name ILIKE $1 OR p.name ILIKE $2) ORDER BY char_length(p.name) ASC LIMIT 1\",['%'+first+'%','%'+w1+'%'])).rows[0];\n" +
"      res.json({ ok:true, slug: prow?prow.slug:null, name: prow?prow.name:null, category:'/category/iptv' });\n" +
"    }catch(e){ res.json({ ok:false }); }\n" +
"  });\n\n";

const anchor = "  // ---- FORGOT / RESET PASSWORD ----";
const i = s.indexOf(anchor);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: added /account/tools/trials + extend + buy');
console.log('TRIALS PATCH OK');
