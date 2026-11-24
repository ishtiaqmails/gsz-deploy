#!/usr/bin/env bash
# diagFooter — dump the footer link hrefs + check each against a real route; confirm city links on /iptv. Read-only.
set -e
cd /opt/zayron
echo "### footer link hrefs (from shellPage in server.js) ###"
grep -noE "href=\"/[a-z0-9/-]*\"[^>]*>[^<]*(player|server|country|device|review|blog|support|refund|shipping|privacy|sitemap|rss|compare|reseller|find|what)[^<]*" server.js | head -40 || true
echo
echo "### explicit footer block (lines around 'All IPTV players') ###"
grep -n "All IPTV players\|All IPTV servers\|IPTV by country\|Devices &amp; sticks\|Setup guides\|Help &amp; fixes\|Brand protection\|What you can watch\|Find my server\|Best IPTV" server.js | head -30 || true
echo
echo "### does the footer reference /players or an anchor? ###"
grep -noE "players?[^\"<]{0,8}\"|/#players|#players|/iptv-players|Players' href|href=\"[^\"]*player[^\"]*\"" server.js | head -20 || true
echo
echo "### active city slugs + are they linked on /iptv (cityLinks query result) ###"
node -e "
const { pool } = require('./db');
(async()=>{ try{
  const c=(await pool.query('SELECT name,slug,active FROM cities ORDER BY sort,id')).rows;
  console.log('cities:', JSON.stringify(c));
}catch(e){console.log('cities err:', e.message)} process.exit(0); })();
"
echo DONE
