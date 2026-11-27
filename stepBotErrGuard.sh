#!/usr/bin/env bash
# stepBotErrGuard — stop gszwabot crash-restart churn (289x). It has no process-level error handlers, so a transient
# throw in the async messages.upsert handler (Bad MAC decrypt, webhook hiccup) becomes an unhandled rejection and, on
# Node 22, kills the process -> pm2 restart. Add global unhandledRejection/uncaughtException guards that LOG and keep
# running; the socket's own close handler still reconnects on real disconnects. Auth/session untouched.
# Safe: backup + single-match + revert + node --check + reconnect verify.
set -e
W=/opt/gsz-wabot; cd "$W"
TS=$(date +%s); B="$W/.retired/$TS"; mkdir -p "$B"; cp bot.js "$B/"
revert(){ cp "$B/bot.js" bot.js; pm2 restart gszwabot >/dev/null 2>&1 || true; }
T="$(mktemp -d)"

cat > "$T/o" <<'O'
const P = require('pino');
const http = require('http');
const https = require('https');
O
cat > "$T/n" <<'O'
const P = require('pino');
const http = require('http');
const https = require('https');

// Global safety net: keep this long-running bot alive through transient Baileys/libsignal throws
// (Bad MAC decrypts, init-query timeouts, webhook hiccups) instead of crashing -> pm2 restart churn.
// The socket's own connection.update 'close' handler still reconnects on a real disconnect.
process.on('unhandledRejection', function (reason) { try { console.error('[wabot] unhandledRejection: ' + ((reason && reason.message) || reason)); } catch (e) {} });
process.on('uncaughtException', function (err) { try { console.error('[wabot] uncaughtException: ' + ((err && err.message) || err)); } catch (e) {} });
O

node - "$T" <<'APPLY'
const fs=require('fs'); const dir=process.argv[2];
function rd(f){ let x=fs.readFileSync(dir+'/'+f,'utf8'); if(x.endsWith('\n')) x=x.slice(0,-1); return x; }
let s=fs.readFileSync('bot.js','utf8'); const O=rd('o'),N=rd('n');
const c=s.split(O).length-1; if(c!==1){console.error('ANCHOR x'+c);process.exit(5);}
s=s.split(O).join(N); fs.writeFileSync('bot.js',s); console.log('bot.js PATCHED OK');
APPLY
[ $? -eq 0 ] || { echo "patch failed - reverting"; cp "$B/bot.js" bot.js; rm -rf "$T"; exit 1; }
rm -rf "$T"

node --check bot.js || { echo "syntax error - reverting"; cp "$B/bot.js" bot.js; exit 1; }
R0=$(pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).find(x=>x.name==='gszwabot').pm2_env.restart_time);}catch(e){console.log('?');}});" 2>/dev/null)
echo "restart_time before: ${R0}"
pm2 restart gszwabot >/dev/null 2>&1 || pm2 restart gszwabot
echo "waiting for reconnect (auth untouched; no re-scan)..."
CONN="no"
for i in $(seq 1 18); do sleep 1; if pm2 logs gszwabot --nostream --lines 60 2>/dev/null | grep -q "\[wabot\] connected as"; then CONN="yes"; break; fi; done
echo "reconnected: ${CONN}"
[ "$CONN" = "yes" ] || { echo "not reconnected - reverting"; revert; exit 1; }
echo "DONE: global error guards added — transient library throws are logged, not fatal. Restart churn should stop. reconnected=${CONN}"
echo "NOTE: watch 'pm2 describe gszwabot' over the next day — restart_time should stay flat now."
