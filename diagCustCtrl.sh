#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### routes/adminCustomers.js (full) ###"
cat routes/adminCustomers.js
echo
echo "### password hash helper location ###"
grep -rnE "function hashPw|hashPw *=|const hashPw|module.exports.*hashPw|exports.hashPw" lib/*.js routes/*.js 2>/dev/null | grep -viE '\.bak|\.xbak' | head
echo
echo "### admin/customers.ejs: detail drawer + fetch of :id.json + where actions go ###"
grep -nE "id.json|drawer|detail|wa_number|email|password|block|unblock|fetch\(|cust|modal|panel" views/admin/customers.ejs 2>/dev/null | grep -viE '\.bak' | head -40
