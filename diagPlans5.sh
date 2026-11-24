#!/usr/bin/env bash
# diagPlans5 — the plan-field contract: what columns server_plans has, and exactly which plan fields the
# server page + checkout read (so a bot-derived plan can match the shape without breaking the money path).
set -e
cd /opt/zayron
echo "### server_plans columns + 2 sample rows ###"
node -e "
const { pool } = require('./db');
(async()=>{
  try{
    const cols=(await pool.query(\"SELECT column_name,data_type FROM information_schema.columns WHERE table_name='server_plans' ORDER BY ordinal_position\")).rows;
    console.log('cols:', cols.map(c=>c.column_name+':'+c.data_type).join(', '));
    const rows=(await pool.query('SELECT * FROM server_plans ORDER BY server_id, sort LIMIT 2')).rows;
    console.log('rows:', JSON.stringify(rows,null,1));
  }catch(e){ console.log('err:', e.message); }
  process.exit(0);
})();
" 2>&1 | head -40
echo
echo "### server.js plan render blocks ###"
for R in '878,900' '995,1016' '1308,1335'; do echo "--- server.js $R ---"; sed -n "${R}p" server.js; done
echo
echo "### checkout.js — how a plan is chosen, priced, and submitted to the bot ###"
grep -n "plan\|submitOrder\|plan_key\|duration\|price\|server_plans\|quote(" routes/checkout.js | head -50 || true
echo DONE
