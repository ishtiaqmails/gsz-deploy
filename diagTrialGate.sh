#!/usr/bin/env bash
# READ-ONLY. Current POST /trial/start top + /providers res.json, to anchor the account-verified gate.
Z=/opt/zayron; cd "$Z"
echo "### signup_otp_on setting ###"
node -e "const{pool}=require('./db');pool.query(\"SELECT key,value FROM settings WHERE key IN ('signup_otp_on','web_trials_on','web_paid_on','store_manual')\").then(r=>{console.log(JSON.stringify(r.rows));process.exit(0)})"
echo
echo "### POST /trial/start (first ~45 lines of handler) ###"
awk '/router\.post\(.\/start./{f=1} f{print NR": "$0} f&&/_isFetchEarly/{c++} c&&/const ip = clientIp/{exit}' routes/trial.js | head -40
echo
echo "### /providers res.json line ###"
grep -n "verifiedLast\|res.json({ ok: true, providers" routes/trial.js
echo DONE
