#!/usr/bin/env bash
# Stage 3 wiring diagnostic — read-only. How routes mount + how the logged-in customer is read.
GSZ=/opt/gsz; cd "$GSZ"
echo "### server.js: router mounts (app.use / require routes) ###"
grep -n "app.use(\|require('./routes\|require(\"./routes" server.js | head -40
echo
echo "### server.js: any /api routes defined inline ###"
grep -n "app.get('/api\|app.post('/api\|/api/announcements\|/api/coupon" server.js routes/*.js 2>/dev/null | grep -v "\.bak" | head
echo
echo "### how a route reads the logged-in customer (session) ###"
grep -rn "req.session\|customerId\|req.customer\|loadCustomer\|requireCustomer\|res.locals.customer" routes/account.js server.js 2>/dev/null | grep -v "\.bak" | head -20
echo
echo "### /api/announcements handler (pattern to copy) ###"
grep -rn "api/announcements" routes/*.js server.js 2>/dev/null | grep -v "\.bak" | head -3
