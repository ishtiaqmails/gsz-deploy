#!/usr/bin/env bash
# dumpCurrency.sh — read-only. How GSZ currently does currency: geo, conversion, REGIONS, client render.
set -uo pipefail
GSZ=/opt/gsz; cd "$GSZ"

echo "### A) geo + currency decision in server.js ###"
grep -nE "CF-IPCountry|cf-ipcountry|geoCountry|forceCur|trust proxy|GEO_FALLBACK|Vary|data-cur|REGIONS" "$GSZ/server.js" 2>/dev/null | head -20

echo
echo "### B) REGIONS definition + rate logic (where conversion happens) ###"
grep -rnE "REGIONS *=|const REGIONS|\.rate\b|price_usd|pkr *\* |usd *=|REGIONS\[" "$GSZ"/lib/*.js "$GSZ"/routes/*.js "$GSZ/server.js" 2>/dev/null | grep -viE "node_modules|\.bak" | grep -iE "REGIONS|rate|usd|pkr" | head -25

echo
echo "### C) is there a live FX source already? (er-api / exchange / rate.js / pricing.js) ###"
ls "$GSZ"/lib/rate.js "$GSZ"/lib/pricing.js "$GSZ"/lib/fx.js 2>/dev/null
grep -rnE "er-api|exchangerate|openexchange|binance|fx_per_usd|fetch.*rate|USD_PKR|live.*rate" "$GSZ"/lib/*.js "$GSZ"/routes/*.js "$GSZ/server.js" 2>/dev/null | grep -v node_modules | head -12

echo
echo "### D) client-side price render (data-cur / currency switch / country picker) ###"
grep -nE "data-cur|gs_cur|curFlag|curLabel|pprice|data-pkr|data-usd|currency" "$GSZ/views/partials/store_top.ejs" 2>/dev/null | head -12
ls "$GSZ"/public/js/*.js 2>/dev/null | head
grep -rnE "data-cur|data-pkr|data-usd|pprice|toLocaleString|Intl.NumberFormat|currency" "$GSZ"/public/js/*.js 2>/dev/null | head -12
echo "== END =="
