#!/usr/bin/env bash
# diagRoutes — enumerate the full public page surface: every app.get route + dynamic page sources
# (server slugs, player slugs, country pages, city pages). Read-only.
set -e
cd /opt/zayron
echo "### all public GET routes in server.js ###"
grep -nE "app\.(get|use)\(['\"]/" server.js | grep -vE "/admin|/healthz|/static|/uploads|/api/|\.txt|\.xml|well-known|robots|sitemap" | head -80 || true
echo
echo "### dynamic page route patterns (server/player/country/city) ###"
grep -nE "/server/:|/player/:|/iptv|/country|/city|/:country|/:city|/:slug|buildCountry|buildCity|COUNTRIES|CITIES" server.js | head -40 || true
echo
echo "### server slugs (active) ###"
node -e "
const { pool } = require('./db');
(async()=>{ try{
  const s=(await pool.query('SELECT slug FROM servers WHERE active=true ORDER BY sort,id')).rows.map(x=>x.slug);
  console.log(s.join('\n'));
}catch(e){console.log(e.message)} process.exit(0); })();
"
echo
echo "### player slugs (if any) ###"
node -e "
const { pool } = require('./db');
(async()=>{ try{
  const s=(await pool.query('SELECT slug FROM players ORDER BY id')).rows.map(x=>x.slug);
  console.log(s.join('\n')||'(none)');
}catch(e){console.log('players: '+e.message)} process.exit(0); })();
"
echo
echo "### country / city page sources ###"
grep -nE "country|city|COUNTRIES|cities|cityList|countryList" server.js | grep -iE "get|slug|route|param|build|map\(|forEach" | head -25 || true
echo DONE
