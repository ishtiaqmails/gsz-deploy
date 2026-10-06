#!/usr/bin/env bash
# step94 — Batch 1: keep customers logged in. Moves sessions from in-memory to
# a Postgres-backed store (connect-pg-simple) with a 30-day cookie, so sessions
# survive page navigation and app restarts. Idempotent; rolls back server.js.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step94-$TS
mkdir -p "$BAK"
cp "$APP/server.js" "$BAK/server.js"
restore(){ echo "!! rollback"; cp "$BAK/server.js" "$APP/server.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> install connect-pg-simple"
npm install connect-pg-simple --no-audit --no-fund 2>&1 | tail -3

echo "==> patch server.js (pg session store + 30-day cookie)"
node <<'NODE'
const fs=require('fs'); const f='/opt/gsz/server.js'; let s=fs.readFileSync(f,'utf8');
if(s.indexOf('connect-pg-simple')>=0){ console.log('   already patched'); process.exit(0); }
const a1="const session = require('express-session');";
if(s.indexOf(a1)<0){ console.error('!! express-session require anchor not found'); process.exit(2); }
s=s.replace(a1, a1+"\nconst pgSession = require('connect-pg-simple')(session);");
const a2="app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));";
if(s.indexOf(a2)<0){ console.error('!! session middleware anchor not found'); process.exit(3); }
const n2="app.use(session({\n"
 +"  store: new pgSession({ pool: pool, tableName: 'user_sessions', createTableIfMissing: true }),\n"
 +"  secret: process.env.SESSION_SECRET,\n"
 +"  resave: false,\n"
 +"  saveUninitialized: false,\n"
 +"  cookie: { maxAge: 30 * 24 * 60 * 60 * 1000, httpOnly: true, sameSite: 'lax' }\n"
 +"}));";
s=s.replace(a2, n2);
fs.writeFileSync(f,s); console.log('   server.js patched');
NODE

echo "==> node --check + restart"; node --check "$APP/server.js"; pm2 restart gsz --update-env >/dev/null; sleep 3
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home broken"; false; }
# confirm the session table was created
node <<'NODE'
require('dotenv').config();
const { Pool } = require('pg');
const p = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS });
p.query("SELECT to_regclass('public.user_sessions') AS t").then(r=>{ console.log('   session table: '+(r.rows[0].t||'(will be created on first login)')); return p.end(); }).catch(()=>p.end());
NODE
trap - ERR
echo "==> step94 OK — sessions now persist in Postgres (30-day cookie). Backup: $BAK"
echo "   Note: you'll sign in to the admin once more (old in-memory sessions were cleared)."
