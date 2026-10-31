#!/usr/bin/env bash
# stepMigrate.sh — Phase 2: create the geo + SEO-core tables. Additive, transactional, idempotent.
# Does NOT restart the app (schema-only; no app code uses these tables yet). Safe to re-run.
set -Eeuo pipefail
GSZ=/opt/gsz; SRC=/opt/gsz-deploy/libsrc
echo "==> running migration 001_geo_seo_core (additive + transactional; app untouched)"
node "$SRC/migrate.js" "$SRC/migrations/001_geo_seo_core.sql"
echo
echo "==> confirm existing site still healthy"
code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true); echo "   homepage HTTP $code"
echo
echo "DONE — foundation tables created. No existing table or route changed, app not restarted."
