'use strict';
/* Trials in the Hub (added to routes/account.js). A trial can ONLY be converted to a paid line
   (same Renew path); there is no "extend". The Convert-to-paid option is offered for 2 days from
   claim, then it disappears.
   - GET /account/tools/trials          -> creds, expiry, days/hours left, status, convertable (<2 days from claim, not converted)
   - GET /account/tools/trials/:id/buy  -> resolves the paid IPTV product matching the trial's service (Convert target)
   Re-appliable: replaces its own prior block. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_trials.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const START = "  // ---- TRIALS (Hub) ----\n";
const END   = "  // ---- END TRIALS (Hub) ----\n";
const ANCHOR = "  // ---- FORGOT / RESET PASSWORD ----";

const ROUTES =
"  // ---- TRIALS (Hub) ----\n" +
"  router.get('/account/tools/trials', requireLogin, async (req, res) => {\n" +
"    const c = req.session.customer; let rows=[], paid=[];\n" +
"    try{ rows=(await pool.query(\"SELECT id, trial_type, server_name, status, credentials, expires_at, duration_hours, claimed_at, metadata FROM trial_claims WHERE customer_id=$1 ORDER BY id DESC LIMIT 25\",[c.id])).rows; }catch(e){}\n" +
"    try{ paid=(await pool.query(\"SELECT product_name, created_at FROM orders WHERE (customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2))) AND order_no IS NOT NULL AND lower(status) IN ('delivered','completed','done','paid','active')\",[c.id,c.email])).rows; }catch(e){}\n" +
"    function convertedByPurchase(server, claimedMs){ try{ const segs=String(server||'').toLowerCase().split(/[\\/|,()]/).map(function(x){return x.trim();}).filter(function(x){return x.length>=4;}); if(!segs.length) return false; return paid.some(function(o){ const pn=String(o.product_name||'').toLowerCase(); const after=o.created_at?(new Date(o.created_at).getTime() > (claimedMs||0)):false; return after && segs.some(function(sg){ return pn.indexOf(sg)>=0; }); }); }catch(e){ return false; } }\n" +
"    const now=Date.now();\n" +
"    res.json({ ok:true, trials: rows.map(function(t){\n" +
"      const md=t.metadata||{}; if(md.gsz_converted||md.converted) return null;\n" +
"      const _claimedMs=t.claimed_at?new Date(t.claimed_at).getTime():0;\n" +
"      if(convertedByPurchase(t.server_name, _claimedMs)) return null;\n" +
"      const claimed=t.claimed_at?new Date(t.claimed_at).getTime():null;\n" +
"      const durH=Number(t.duration_hours)||0;\n" +
"      const dbExp=t.expires_at?new Date(t.expires_at).getTime():null;\n" +
"      // a trial's real window is claim + its duration; ignore a bogus expires_at\n" +
"      const exp=(claimed && durH) ? (claimed + durH*3600000) : dbExp;\n" +
"      const msLeft=exp!=null?(exp-now):null;\n" +
"      const st=String(t.status||'').toLowerCase();\n" +
"      const done=['active','delivered','done','completed'].indexOf(st)>=0;\n" +
"      const windowOpen = claimed ? (now < claimed + 2*86400000) : false;\n" +
"      return { id:t.id, server:t.server_name||t.trial_type||'IPTV trial', credentials: done?(t.credentials||''):'',\n" +
"        status:t.status, pending: st==='pending', claimed:t.claimed_at, duration_hours: durH||null,\n" +
"        expires: exp!=null?new Date(exp).toISOString():t.expires_at,\n" +
"        active: exp!=null?(exp>now):true, days_left: exp!=null?Math.floor(msLeft/86400000):null, hours_left: exp!=null?Math.ceil(msLeft/3600000):null,\n" +
"        convertable: windowOpen };\n" +
"    }).filter(Boolean) });\n" +
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
"  });\n" +
"  // ---- END TRIALS (Hub) ----\n\n";

// remove any prior TRIALS block precisely (START .. END), so neighbouring routes (e.g. profile) survive
const si = s.indexOf(START);
if (si >= 0) {
  const ei = s.indexOf(END, si);
  if (ei >= 0) { let cut = ei + END.length; while (s[cut] === '\n') cut++; s = s.slice(0, si) + s.slice(cut); }
  else { const ai = s.indexOf(ANCHOR, si); if (ai >= 0) s = s.slice(0, si) + s.slice(ai); } // legacy block w/o END marker
}
const i = s.indexOf(ANCHOR);
if (i < 0) throw new Error('ANCHOR MISS: FORGOT/RESET comment not found in account.js');
s = s.slice(0, i) + ROUTES + s.slice(i);
fs.writeFileSync(file, s);
console.log('patched: /account/tools/trials (convert-only, 2-day window) + buy');
console.log('TRIALS PATCH OK');
