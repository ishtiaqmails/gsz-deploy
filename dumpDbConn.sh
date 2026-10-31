#!/usr/bin/env bash
# dumpDbConn.sh — read-only. How the app connects to Postgres, so migrations use the SAME method
# (never guess creds). Shows connection CODE + the DB-related .env KEY NAMES (values hidden).
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"
echo "### A) pg connection code (new Pool / DATABASE_URL / db module) ###"
grep -rnE "new Pool\(|DATABASE_URL|require\('pg'\)|PGHOST|DB_HOST|DB_NAME|connectionString" server.js lib/*.js 2>/dev/null | grep -viE "node_modules|\.bak" | head -20
echo
echo "### B) is there a shared db module? ###"
ls -1 lib/*.js 2>/dev/null | grep -iE "db|database|pool|pg" | head
grep -rlnE "module.exports.*Pool|new Pool" lib/*.js 2>/dev/null | grep -v node_modules | head
echo
echo "### C) DB-related .env KEY NAMES only (values hidden) ###"
if [ -f .env ]; then
  grep -iE '^(DATABASE_URL|DB_|PG|POSTGRES|PedB)' .env 2>/dev/null | sed -E 's/=.*/=<hidden>/' | head -20
else echo "(no .env at $GSZ/.env)"; fi
echo
echo "### D) how the main app process gets its env (pm2 ecosystem / dotenv) ###"
grep -rnE "dotenv|require\('dotenv'\)|ecosystem|env_file" server.js 2>/dev/null | head
ls -1 ecosystem*.js* 2>/dev/null | head
echo "== END =="
