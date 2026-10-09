#!/usr/bin/env bash
GSZ=/opt/gsz; cd "$GSZ" || exit 1
export PGPASSWORD="$(grep -E '^DB_PASS=' .env | cut -d= -f2-)"
DBN="$(grep -E '^DB_NAME=' .env | cut -d= -f2-)"; DBU="$(grep -E '^DB_USER=' .env | cut -d= -f2-)"; DBH="$(grep -E '^DB_HOST=' .env | cut -d= -f2-)"
psql -h "${DBH:-localhost}" -U "$DBU" -d "$DBN" -c \
"SELECT id, status,
        (provider_message_id IS NOT NULL) AS got_msgid,
        destination_phone AS dest,
        attempts, sent_at::timestamp(0) AS sent,
        left(coalesce(last_error,''),40) AS err
 FROM wa_notifications
 WHERE template_key='whatsapp.trial_ready'
 ORDER BY id DESC"
echo "== done =="
