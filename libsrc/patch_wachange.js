'use strict';
/* When a customer changes their WhatsApp number (routes/account.js, /account/tools/profile
   field='wa'), also UNLINK the old active WhatsApp link so the account is truly unverified
   and re-verification issues a fresh code. Without this, waStatus() still sees the old
   ACTIVE link and verification short-circuits as "already verified". Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_wachange.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/account.js');
let s = fs.readFileSync(file, 'utf8');

const OLD = 'await pool.query("UPDATE customers SET wa_number=$1, wa_verified=false WHERE id=$2",[d,c.id]);';
const ADD = ' await pool.query("UPDATE customer_whatsapp_links SET status=\'UNLINKED\', is_primary=false, unlinked_at=now(), updated_at=now() WHERE customer_id=$1 AND status=\'ACTIVE\'",[c.id]);';

if (s.indexOf("status='UNLINKED', is_primary=false, unlinked_at=now()") >= 0) { console.log('wa-change unlink: already present (skip)'); }
else if (s.indexOf(OLD) >= 0) { s = s.replace(OLD, OLD + ADD); fs.writeFileSync(file, s); console.log('wa-change unlink: old link unlinked on number change'); }
else { console.error('PATCH FAILED — wa-change anchor not found'); process.exit(2); }
console.log('WACHANGE OK');
