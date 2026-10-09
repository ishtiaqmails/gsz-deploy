#!/usr/bin/env bash
# dumpWaOutbox (compact) — outbox status for trial messages only. No message bodies.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
Q(){ psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" "$@"; }

echo "columns: $(Q -tAc "SELECT string_agg(column_name,',') FROM information_schema.columns WHERE table_name='wa_notifications'")"
echo
echo "## status tally by template ##"
Q -c "SELECT template_key, status, count(*) FROM wa_notifications GROUP BY 1,2 ORDER BY 1,2"
echo "## trial messages (status only) ##"
Q -c "SELECT id, status, destination_identity_id AS dest, created_at::timestamp(0) FROM wa_notifications WHERE template_key LIKE '%trial%' ORDER BY id DESC LIMIT 12" 2>&1 | head -20
echo "## any error column values (recent) ##"
Q -tAc "SELECT id||' '||status||' '||left(coalesce(last_error,error_text,error,note,''),70) FROM wa_notifications ORDER BY id DESC LIMIT 12" 2>&1 | head -14
echo
echo "## wa bot status + verify number (settings) ##"
Q -c "SELECT key, left(value,40) FROM wa_settings WHERE key IN ('wa_bot_status','wa_verify_number','wa_verification_enabled','wa_send_url')"
echo "== done =="
