#!/usr/bin/env bash
# stepBotRetryPersist — fix the verification bot "Waiting for this message" multi-device issue. The bot answers
# WhatsApp retry-receipts via getMessage + an in-memory sentStore, but 288 process restarts keep wiping it, so retries
# after a restart go unanswered. Fix: persist the sent-message store to disk (survives restarts) + add
# msgRetryCounterCache for proper retry handling. Auth/session untouched (reconnects, no re-scan). Safe: backup +
# single-match + revert + node --check + reconnect verify.
set -e
W=/opt/gsz-wabot; cd "$W"
TS=$(date +%s); B="$W/.retired/$TS"; mkdir -p "$B"; cp bot.js "$B/"
revert(){ cp "$B/bot.js" bot.js; pm2 restart gszwabot >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

# ---- E1: persistent sentStore + retry-counter cache ----
cat > "$T/e1_o" <<'O'
const sentStore = new Map(); // message id -> WAMessageContent
function remember(id, content) { if (!id || !content) return; sentStore.set(id, content); if (sentStore.size > 1500) { sentStore.delete(sentStore.keys().next().value); } }
O
cat > "$T/e1_n" <<'O'
const sentStore = new Map(); // message id -> WAMessageContent
const msgRetryCounterCache = new Map(); // Baileys retry-count tracking (proper retry handling)
const _fsSent = require('fs'); const _pathSent = require('path');
const SENT_FILE = _pathSent.join(__dirname, 'sent-cache.json');
// Load the sent-message store from disk so retry-receipts are answered even after a restart
// (this is what clears the recipient-side "Waiting for this message. This may take a while.").
try { const _raw = _fsSent.readFileSync(SENT_FILE, 'utf8'); const _arr = JSON.parse(_raw); if (Array.isArray(_arr)) _arr.forEach(function (e) { if (e && e.id) sentStore.set(e.id, e.content); }); } catch (e) {}
let _sentFlushT = null;
function _flushSent() { try { const a = []; for (const pair of sentStore) a.push({ id: pair[0], content: pair[1] }); _fsSent.writeFileSync(SENT_FILE, JSON.stringify(a.slice(-800))); } catch (e) {} }
function remember(id, content) { if (!id || !content) return; sentStore.set(id, content); if (sentStore.size > 1500) { sentStore.delete(sentStore.keys().next().value); } if (_sentFlushT) clearTimeout(_sentFlushT); _sentFlushT = setTimeout(_flushSent, 1500); }
O

# ---- E2: pass msgRetryCounterCache to the socket ----
cat > "$T/e2_o" <<'O'
    logger, markOnlineOnConnect: false, syncFullHistory: false,
    // Resend on retry-receipt so recipients never get stuck on "Waiting for this message".
    getMessage: async (key) => { return sentStore.get(key.id) || undefined; }
O
cat > "$T/e2_n" <<'O'
    logger, markOnlineOnConnect: false, syncFullHistory: false,
    msgRetryCounterCache,
    // Resend on retry-receipt so recipients never get stuck on "Waiting for this message".
    getMessage: async (key) => { return sentStore.get(key.id) || undefined; }
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('bot.js','utf8');
for(const [o,n] of [['e1_o','e1_n'],['e2_o','e2_n']]){ const O=rd(o),N=rd(n); const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR '+o+' x'+c);process.exit(5);} s=s.split(O).join(N); }
fs.writeFileSync('bot.js',s); console.log('bot.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; cp "$B/bot.js" bot.js; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check bot.js || { echo "syntax error - reverting"; cp "$B/bot.js" bot.js; exit 1; }
pm2 restart gszwabot >/dev/null 2>&1 || pm2 restart gszwabot
echo "waiting for the bot to reconnect (no re-scan; auth folder untouched)..."
CONN="no"
for i in $(seq 1 18); do sleep 1; if pm2 logs gszwabot --nostream --lines 60 2>/dev/null | grep -q "\[wabot\] connected as"; then CONN="yes"; break; fi; done
echo "reconnected: ${CONN}"
pm2 logs gszwabot --nostream --lines 30 2>/dev/null | grep -iE "connected as|Scan this QR|closed \(" | tail -5
if [ "$CONN" != "yes" ]; then echo "NOT reconnected yet — if a QR shows, this is unrelated to the change (session), but reverting bot.js to be safe"; revert; echo "reverted. Check 'pm2 logs gszwabot'."; exit 1; fi
echo "DONE: sent-message store now persists to disk (retries survive restarts) + msgRetryCounterCache added. Reconnected=${CONN}."
