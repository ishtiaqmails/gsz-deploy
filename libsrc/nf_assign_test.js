'use strict';
/* Controlled assign test — exercises the NEW write path via the deployed lib/nfPortal.assign,
   then cleans up (unassign the account + delete the test customer). Safe: uses a clearly-named
   test customer and 1-day assignment, and restores the free account afterwards.
   Run:  node /opt/gsz-deploy/libsrc/nf_assign_test.js /opt/gsz  [productOldId]  */
const R = process.argv[2] || '/opt/gsz';
const PID = process.argv[3] || 1; // Netflix old_id by default
require(R + '/node_modules/dotenv').config({ path: R + '/.env' });
const https = require('https'); const { URL } = require('url');
const BASE = (process.env.NF_PORTAL_URL || '').replace(/\/+$/, ''); const KEY = process.env.NF_READ_KEY || '';
const nfPortal = require(R + '/lib/nfPortal');

function api(method, path, body) {
  return new Promise((r) => {
    try {
      const u = new URL(BASE + path);
      const data = body != null ? Buffer.from(JSON.stringify(body)) : null;
      const h = { Authorization: 'Bearer ' + KEY, Accept: 'application/json' };
      if (data) { h['Content-Type'] = 'application/json'; h['Content-Length'] = data.length; }
      const q = https.request({ hostname: u.hostname, port: 443, path: u.pathname + u.search, method, headers: h }, (res) => {
        let b = ''; res.on('data', d => b += d); res.on('end', () => { let j = null; try { j = JSON.parse(b); } catch (e) {} r({ s: res.statusCode, j }); });
      });
      q.on('error', e => r({ s: 0, err: e.message })); q.setTimeout(20000, () => q.destroy());
      if (data) q.write(data); q.end();
    } catch (e) { r({ s: 0, err: e.message }); }
  });
}

(async () => {
  console.log('configured:', nfPortal.configured(), '| base:', BASE);
  const uname = 'gsz-migrate-test';
  console.log('\n1) assign via lib/nfPortal.assign (product old_id ' + PID + ', 1 day)…');
  const r = await nfPortal.assign({ productId: PID, buyerName: uname, buyerWhatsApp: '923000000000', days: 1 });
  console.log(JSON.stringify(r, null, 1));
  const good = r && r.ok && r.assignedEmail && r.portalUrl && r.customerUsername;
  console.log(good ? '   -> PASS: assign returned email + portal_url + customer login' : '   -> CHECK: missing fields (see above)');

  if (r && r.ok && r.accountId) {
    console.log('\n2) cleanup: unassign account ' + r.accountId + '…');
    const un = await api('POST', '/accounts/' + r.accountId + '/unassign', {});
    console.log('   unassign:', un.s, JSON.stringify(un.j || un.err || ''));
  }
  console.log('\n3) cleanup: delete test customer…');
  const cs = await api('GET', '/customers?q=' + encodeURIComponent(uname));
  const cust = cs.j && cs.j.customers && cs.j.customers.find(x => x.username === uname);
  if (cust) { const del = await api('DELETE', '/customers/' + cust.id, {}); console.log('   delete customer ' + cust.id + ':', del.s, JSON.stringify(del.j || del.err || '')); }
  else console.log('   (test customer not found to delete — ok)');
  console.log('\nDONE — if step 1 is PASS, the assign/delivery path is good.');
})().catch(e => console.error('ERR', e.message));
