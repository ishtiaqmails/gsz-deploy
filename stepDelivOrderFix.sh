#!/usr/bin/env bash
# Deterministic customer-message order: Received -> Payment -> Login -> Instructions.
# Single point: wanotify worker orders by scheduled time, and enqueue() assigns a
# tiny sequence offset from the existing idempotency-key suffix.
node <<'EOF'
const fs=require('fs');
const f='/opt/gsz/lib/wanotify.js';
const orig=fs.readFileSync(f,'utf8');
let s=orig;
function rep(a,b){ const n=s.split(a).length-1; if(n!==1){ throw new Error('anchor x'+n+' :: '+a.slice(0,46)); } s=s.split(a).join(b); }
try{
  rep('ORDER BY queued_at LIMIT 5','ORDER BY next_attempt_at, queued_at LIMIT 5');
  rep('const _delay = Number(o.delay_seconds) || 0;',
      "const _SEQ = { new:0, paid:2, delivered:4, instructions:6 };\n    const _mm = String(o.idempotency_key||'').match(/-(new|paid|delivered|instructions)$/);\n    const _delay = Math.max(Number(o.delay_seconds)||0, _mm ? _SEQ[_mm[1]] : 0);");
}catch(e){ console.log('FAIL '+e.message); process.exit(1); }
const bak=f+'.bak.'+Date.now();
fs.writeFileSync(bak,orig);
fs.writeFileSync(f,s);
try{ require('child_process').execSync('node -c '+f); }
catch(e){ fs.writeFileSync(f,orig); console.log('FAIL node -c, reverted'); process.exit(1); }
console.log('OK wanotify.js patched  [backup '+bak+']');
EOF
echo "--- which process runs the wa outbox worker ---"
grep -rln "startWorker" /opt/gsz/*.js /opt/gsz/routes/*.js /opt/gsz/lib/*.js 2>/dev/null
echo "--- restart site ---"
pm2 restart gsz >/dev/null 2>&1 && echo "gsz restarted" || echo "restart failed"
