#!/usr/bin/env bash
# step77 — WhatsApp module Phase 2a: identity FOUNDATION (invisible, additive).
# Adds tables (whatsapp_identities, aliases, customer links, verification
# sessions, phone history, trial_claims, notifications outbox, audit log),
# customer ref_code + marketing-consent columns, namespaced wa_settings +
# wa_templates with safe defaults, and the lib/waidentity.js resolver.
# NO server.js / view changes -> nothing visible changes, nothing can break.
set -euo pipefail
APP=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
BAK=$APP/.bak-step77-$TS
mkdir -p "$BAK/lib"
[ -f "$APP/lib/waidentity.js" ] && cp "$APP/lib/waidentity.js" "$BAK/lib/waidentity.js" || true
restore(){ echo "!! rollback (files only; DB objects are IF NOT EXISTS / additive)"; [ -f "$BAK/lib/waidentity.js" ] && cp "$BAK/lib/waidentity.js" "$APP/lib/waidentity.js" || rm -f "$APP/lib/waidentity.js"; pm2 restart gsz --update-env >/dev/null 2>&1 || true; }
trap 'restore' ERR
cd "$APP"

echo "==> write lib/waidentity.js"
base64 -d > "$APP/lib/waidentity.js" <<'B64'
J3VzZSBzdHJpY3QnOwovKiBXaGF0c0FwcCBpZGVudGl0eSBlbmdpbmUg4oCUIG5vcm1hbGl6YXRpb24gKyBhbGlhcy1iYXNlZCByZXNvbHV0aW9uLgogICBUaGUgTElEIGlzIHRoZSBjYW5vbmljYWwgcGVyc2lzdGVudCBpZGVudGl0eTsgcGhvbmUgbnVtYmVycyBhcmUgY29udGFjdAogICBkYXRhIHRoYXQgY2FuIGNoYW5nZS4gT25lIGlkZW50aXR5IG1heSBzdXJmYWNlIHVuZGVyIHNldmVyYWwgaWRlbnRpZmllcnMKICAgKExJRCwgUE4gSklELCBwaG9uZSkuIFRoaXMgbW9kdWxlIHJlc29sdmVzIHRoZW0gdG8gYSBzaW5nbGUgaWRlbnRpdHkgcm93CiAgIGFuZCBuZXZlciBjcmVhdGVzIGR1cGxpY2F0ZXMgd2hlbiB0aGUgc2FtZSBpZGVudGl0eSBhcHBlYXJzIHR3byB3YXlzLgogICBUaGUgbm9ybWFsaXplIGFuZCBjbGFzc2lmeSBoZWxwZXJzIGhhdmUgbm8gREIgZGVwcyBhbmQgYXJlIHVuaXQtdGVzdGVkLiAqLwoKLy8gLS0tLSBwdXJlIG5vcm1hbGl6YXRpb24gaGVscGVycyAtLS0tCmZ1bmN0aW9uIG5vcm1hbGl6ZUxpZChyYXcpIHsKICBpZiAoIXJhdykgcmV0dXJuIG51bGw7CiAgY29uc3QgcyA9IFN0cmluZyhyYXcpLnRyaW0oKS50b0xvd2VyQ2FzZSgpOwogIGNvbnN0IG0gPSBzLm1hdGNoKC8oXGR7NSx9KSg/Ols6QF18JCkvKTsgLy8gZGlnaXRzIGJlZm9yZSBAbGlkIC8gOmRldmljZSAvIGVuZAogIHJldHVybiBtID8gbVsxXSA6ICgvXlxkezUsfSQvLnRlc3QocykgPyBzIDogbnVsbCk7Cn0KZnVuY3Rpb24gbm9ybWFsaXplUGhvbmVFMTY0KHJhdykgewogIGlmICghcmF3KSByZXR1cm4gbnVsbDsKICBsZXQgcyA9IFN0cmluZyhyYXcpLnRyaW0oKTsKICBzID0gcy5zcGxpdCgnQCcpWzBdOyAgICAgICAgICAgICAgICAgLy8gZHJvcCBAcy53aGF0c2FwcC5uZXQgZXRjLgogIHMgPSBzLnJlcGxhY2UoL1teXGQrXS9nLCAnJyk7ICAgICAgICAgLy8ga2VlcCBkaWdpdHMgYW5kICsKICBzID0gcy5yZXBsYWNlKC9eMDAvLCAnJyk7ICAgICAgICAgICAgIC8vIGludGwgMDAgcHJlZml4CiAgcyA9IHMucmVwbGFjZSgvW15cZF0vZywgJycpOyAgICAgICAgICAvLyBkaWdpdHMgb25seSBub3cKICBpZiAocy5sZW5ndGggPCA4IHx8IHMubGVuZ3RoID4gMTUpIHJldHVybiBudWxsOwogIHJldHVybiAnKycgKyBzOwp9CmZ1bmN0aW9uIG5vcm1hbGl6ZUppZChyYXcpIHsKICBpZiAoIXJhdykgcmV0dXJuIG51bGw7CiAgcmV0dXJuIFN0cmluZyhyYXcpLnRyaW0oKS50b0xvd2VyQ2FzZSgpOwp9CmZ1bmN0aW9uIGNsYXNzaWZ5SWRlbnRpZmllcihyYXcpIHsKICBjb25zdCBzID0gbm9ybWFsaXplSmlkKHJhdyk7CiAgaWYgKCFzKSByZXR1cm4gJ1VOS05PV04nOwogIGlmIChzLmVuZHNXaXRoKCdAbGlkJykpIHJldHVybiAnTElEJzsKICBpZiAocy5lbmRzV2l0aCgnQHMud2hhdHNhcHAubmV0JykgfHwgcy5lbmRzV2l0aCgnQGMudXMnKSkgcmV0dXJuICdQTl9KSUQnOwogIGlmICgvXlwrP1xkezgsMTV9JC8udGVzdChzKSkgcmV0dXJuICdQSE9ORV9FMTY0JzsKICBpZiAoL15cZHs1LH0kLy50ZXN0KHMpKSByZXR1cm4gJ0xJRCc7CiAgcmV0dXJuICdVTktOT1dOJzsKfQoKLy8gQnVpbGQgdGhlIGxpc3Qgb2Yge2lkZW50aWZpZXJfdHlwZSwgaWRlbnRpZmllcl92YWx1ZSwgbm9ybWFsaXplZF92YWx1ZX0gZnJvbSBhIHJhdyBldmVudC4KZnVuY3Rpb24gaWRlbnRpZmllcnNGcm9tKHBhcnRzKSB7CiAgY29uc3Qgb3V0ID0gW107CiAgY29uc3QgcHVzaCA9ICh0eXBlLCB2YWx1ZSwgbm9ybSkgPT4geyBpZiAodmFsdWUgJiYgbm9ybSkgb3V0LnB1c2goeyBpZGVudGlmaWVyX3R5cGU6IHR5cGUsIGlkZW50aWZpZXJfdmFsdWU6IFN0cmluZyh2YWx1ZSksIG5vcm1hbGl6ZWRfdmFsdWU6IG5vcm0gfSk7IH07CiAgaWYgKHBhcnRzLmxpZCkgcHVzaCgnTElEJywgcGFydHMubGlkLCBub3JtYWxpemVMaWQocGFydHMubGlkKSk7CiAgaWYgKHBhcnRzLnBuSmlkKSBwdXNoKCdQTl9KSUQnLCBwYXJ0cy5wbkppZCwgbm9ybWFsaXplSmlkKHBhcnRzLnBuSmlkKSk7CiAgY29uc3QgcGhvbmUgPSBwYXJ0cy5waG9uZSB8fCBwYXJ0cy5wbkppZDsKICBjb25zdCBlMTY0ID0gbm9ybWFsaXplUGhvbmVFMTY0KHBob25lKTsKICBpZiAoZTE2NCkgcHVzaCgnUEhPTkVfRTE2NCcsIHBob25lLCBlMTY0KTsKICAvLyBkZS1kdXBlIGJ5IHR5cGUrbm9ybQogIGNvbnN0IHNlZW4gPSB7fTsgcmV0dXJuIG91dC5maWx0ZXIoeCA9PiB7IGNvbnN0IGsgPSB4LmlkZW50aWZpZXJfdHlwZSArICd8JyArIHgubm9ybWFsaXplZF92YWx1ZTsgaWYgKHNlZW5ba10pIHJldHVybiBmYWxzZTsgc2VlbltrXSA9IDE7IHJldHVybiB0cnVlOyB9KTsKfQoKLyogUmVzb2x2ZSBhbiBpbmNvbWluZyBXaGF0c0FwcCBldmVudCB0byBhIHNpbmdsZSBpZGVudGl0eSByb3csIGNyZWF0aW5nIGl0IGlmCiAgIG5ldy4gTXVzdCBiZSBjYWxsZWQgaW5zaWRlIGEgdHJhbnNhY3Rpb24gKHBhc3MgYSBjb25uZWN0ZWQgY2xpZW50IGBjYCkuCiAgIFJldHVybnMgeyBpZGVudGl0eSwgY3JlYXRlZCwgaWRzQWRkZWQgfS4gQWxpYXMgdW5pcXVlbmVzcyBvbgogICAoaWRlbnRpZmllcl90eXBlLCBub3JtYWxpemVkX3ZhbHVlKSBtYWtlcyBjb25jdXJyZW50IGluc2VydHMgY29udmVyZ2UuICovCmFzeW5jIGZ1bmN0aW9uIHJlc29sdmVPckNyZWF0ZUlkZW50aXR5KGMsIHBhcnRzLCBvcHRzKSB7CiAgb3B0cyA9IG9wdHMgfHwge307CiAgY29uc3QgaWRzID0gaWRlbnRpZmllcnNGcm9tKHBhcnRzKTsKICBpZiAoIWlkcy5sZW5ndGgpIHRocm93IG5ldyBFcnJvcignbm8gdXNhYmxlIFdoYXRzQXBwIGlkZW50aWZpZXJzIGluIGV2ZW50Jyk7CgogIC8vIDEpIGZpbmQgYW4gZXhpc3RpbmcgaWRlbnRpdHkgdmlhIGFueSBhbGlhcwogIGxldCBpZGVudGl0eUlkID0gbnVsbDsKICBmb3IgKGNvbnN0IGlkIG9mIGlkcykgewogICAgY29uc3QgciA9IGF3YWl0IGMucXVlcnkoCiAgICAgICdTRUxFQ1Qgd2hhdHNhcHBfaWRlbnRpdHlfaWQgRlJPTSB3aGF0c2FwcF9pZGVudGl0eV9hbGlhc2VzIFdIRVJFIGlkZW50aWZpZXJfdHlwZT0kMSBBTkQgbm9ybWFsaXplZF92YWx1ZT0kMiBMSU1JVCAxJywKICAgICAgW2lkLmlkZW50aWZpZXJfdHlwZSwgaWQubm9ybWFsaXplZF92YWx1ZV0pOwogICAgaWYgKHIucm93c1swXSkgeyBpZGVudGl0eUlkID0gci5yb3dzWzBdLndoYXRzYXBwX2lkZW50aXR5X2lkOyBicmVhazsgfQogIH0KCiAgY29uc3QgbGlkID0gKGlkcy5maW5kKHggPT4geC5pZGVudGlmaWVyX3R5cGUgPT09ICdMSUQnKSB8fCB7fSkubm9ybWFsaXplZF92YWx1ZSB8fCBudWxsOwogIGNvbnN0IGUxNjQgPSAoaWRzLmZpbmQoeCA9PiB4LmlkZW50aWZpZXJfdHlwZSA9PT0gJ1BIT05FX0UxNjQnKSB8fCB7fSkubm9ybWFsaXplZF92YWx1ZSB8fCBudWxsOwogIGNvbnN0IHBob25lU291cmNlID0gZTE2NCA/IChvcHRzLnBob25lU291cmNlIHx8IChwYXJ0cy5waG9uZSA/ICdVU0VSX1NIQVJFRCcgOiAnUkVNT1RFX0pJRCcpKSA6IG51bGw7CiAgbGV0IGNyZWF0ZWQgPSBmYWxzZTsKCiAgLy8gMikgY3JlYXRlIGlmIG5vbmUKICBpZiAoIWlkZW50aXR5SWQpIHsKICAgIGNvbnN0IHIgPSBhd2FpdCBjLnF1ZXJ5KAogICAgICBgSU5TRVJUIElOVE8gd2hhdHNhcHBfaWRlbnRpdGllcyhjYW5vbmljYWxfbGlkLCBjdXJyZW50X3Bob25lX2UxNjQsIGN1cnJlbnRfcGhvbmVfdmVyaWZpZWQsIHBob25lX3NvdXJjZSwgc3RhdHVzLCBmaXJzdF9zZWVuX2F0LCBsYXN0X3NlZW5fYXQpCiAgICAgICBWQUxVRVMoJDEsJDIsJDMsJDQsJ0FDVElWRScsIG5vdygpLCBub3coKSkgUkVUVVJOSU5HICpgLAogICAgICBbbGlkLCBlMTY0LCBlMTY0ID8gISFvcHRzLnBob25lVmVyaWZpZWQgOiBmYWxzZSwgcGhvbmVTb3VyY2VdKTsKICAgIGlkZW50aXR5SWQgPSByLnJvd3NbMF0uaWQ7CiAgICBjcmVhdGVkID0gdHJ1ZTsKICAgIGlmIChlMTY0KSBhd2FpdCBjLnF1ZXJ5KAogICAgICBgSU5TRVJUIElOVE8gd2hhdHNhcHBfcGhvbmVfaGlzdG9yeSh3aGF0c2FwcF9pZGVudGl0eV9pZCwgcGhvbmVfZTE2NCwgcGhvbmVfc291cmNlLCB2ZXJpZmllZCwgdmFsaWRfZnJvbSwgY2hhbmdlX3JlYXNvbikKICAgICAgIFZBTFVFUygkMSwkMiwkMywkNCwgbm93KCksICdJTklUSUFMX1ZFUklGSUNBVElPTicpYCwgW2lkZW50aXR5SWQsIGUxNjQsIHBob25lU291cmNlLCAhIW9wdHMucGhvbmVWZXJpZmllZF0pOwogIH0gZWxzZSB7CiAgICBhd2FpdCBjLnF1ZXJ5KCdVUERBVEUgd2hhdHNhcHBfaWRlbnRpdGllcyBTRVQgbGFzdF9zZWVuX2F0PW5vdygpLCB1cGRhdGVkX2F0PW5vdygpIFdIRVJFIGlkPSQxJywgW2lkZW50aXR5SWRdKTsKICAgIC8vIGZpbGwgY2Fub25pY2FsX2xpZCAvIHBob25lIGlmIHdlIG5vdyBsZWFybmVkIHRoZW0gYW5kIHRoZXkgd2VyZSBtaXNzaW5nCiAgICBpZiAobGlkKSBhd2FpdCBjLnF1ZXJ5KCdVUERBVEUgd2hhdHNhcHBfaWRlbnRpdGllcyBTRVQgY2Fub25pY2FsX2xpZD1DT0FMRVNDRShjYW5vbmljYWxfbGlkLCQyKSBXSEVSRSBpZD0kMScsIFtpZGVudGl0eUlkLCBsaWRdKTsKICAgIGlmIChlMTY0KSB7CiAgICAgIGNvbnN0IGN1ciA9IChhd2FpdCBjLnF1ZXJ5KCdTRUxFQ1QgY3VycmVudF9waG9uZV9lMTY0IEZST00gd2hhdHNhcHBfaWRlbnRpdGllcyBXSEVSRSBpZD0kMScsIFtpZGVudGl0eUlkXSkpLnJvd3NbMF07CiAgICAgIGlmIChjdXIgJiYgIWN1ci5jdXJyZW50X3Bob25lX2UxNjQpIHsKICAgICAgICBhd2FpdCBjLnF1ZXJ5KCdVUERBVEUgd2hhdHNhcHBfaWRlbnRpdGllcyBTRVQgY3VycmVudF9waG9uZV9lMTY0PSQyLCBwaG9uZV9zb3VyY2U9JDMsIGN1cnJlbnRfcGhvbmVfdmVyaWZpZWQ9JDQgV0hFUkUgaWQ9JDEnLAogICAgICAgICAgW2lkZW50aXR5SWQsIGUxNjQsIHBob25lU291cmNlLCAhIW9wdHMucGhvbmVWZXJpZmllZF0pOwogICAgICAgIGF3YWl0IGMucXVlcnkoCiAgICAgICAgICBgSU5TRVJUIElOVE8gd2hhdHNhcHBfcGhvbmVfaGlzdG9yeSh3aGF0c2FwcF9pZGVudGl0eV9pZCwgcGhvbmVfZTE2NCwgcGhvbmVfc291cmNlLCB2ZXJpZmllZCwgdmFsaWRfZnJvbSwgY2hhbmdlX3JlYXNvbikKICAgICAgICAgICBWQUxVRVMoJDEsJDIsJDMsJDQsIG5vdygpLCAnSU5JVElBTF9WRVJJRklDQVRJT04nKWAsIFtpZGVudGl0eUlkLCBlMTY0LCBwaG9uZVNvdXJjZSwgISFvcHRzLnBob25lVmVyaWZpZWRdKTsKICAgICAgfQogICAgfQogIH0KCiAgLy8gMykgdXBzZXJ0IGFsaWFzZXMgKHVuaXF1ZSBvbiB0eXBlK25vcm1hbGl6ZWQgY29udmVyZ2VzIHJhY2VzIG9udG8gb25lIGlkZW50aXR5KQogIGxldCBpZHNBZGRlZCA9IDA7CiAgZm9yIChjb25zdCBpZCBvZiBpZHMpIHsKICAgIGNvbnN0IHVwID0gYXdhaXQgYy5xdWVyeSgKICAgICAgYElOU0VSVCBJTlRPIHdoYXRzYXBwX2lkZW50aXR5X2FsaWFzZXMod2hhdHNhcHBfaWRlbnRpdHlfaWQsIGlkZW50aWZpZXJfdHlwZSwgaWRlbnRpZmllcl92YWx1ZSwgbm9ybWFsaXplZF92YWx1ZSwgZmlyc3Rfc2Vlbl9hdCwgbGFzdF9zZWVuX2F0LCBpc19hY3RpdmUpCiAgICAgICBWQUxVRVMoJDEsJDIsJDMsJDQsIG5vdygpLCBub3coKSwgdHJ1ZSkKICAgICAgIE9OIENPTkZMSUNUKGlkZW50aWZpZXJfdHlwZSwgbm9ybWFsaXplZF92YWx1ZSkKICAgICAgIERPIFVQREFURSBTRVQgbGFzdF9zZWVuX2F0PW5vdygpLCBpc19hY3RpdmU9dHJ1ZQogICAgICAgUkVUVVJOSU5HICh4bWF4PTApIEFTIGluc2VydGVkYCwKICAgICAgW2lkZW50aXR5SWQsIGlkLmlkZW50aWZpZXJfdHlwZSwgaWQuaWRlbnRpZmllcl92YWx1ZSwgaWQubm9ybWFsaXplZF92YWx1ZV0pOwogICAgaWYgKHVwLnJvd3NbMF0gJiYgdXAucm93c1swXS5pbnNlcnRlZCkgaWRzQWRkZWQrKzsKICB9CgogIGNvbnN0IGlkZW50aXR5ID0gKGF3YWl0IGMucXVlcnkoJ1NFTEVDVCAqIEZST00gd2hhdHNhcHBfaWRlbnRpdGllcyBXSEVSRSBpZD0kMScsIFtpZGVudGl0eUlkXSkpLnJvd3NbMF07CiAgcmV0dXJuIHsgaWRlbnRpdHksIGNyZWF0ZWQsIGlkc0FkZGVkIH07Cn0KCm1vZHVsZS5leHBvcnRzID0geyBub3JtYWxpemVMaWQsIG5vcm1hbGl6ZVBob25lRTE2NCwgbm9ybWFsaXplSmlkLCBjbGFzc2lmeUlkZW50aWZpZXIsIGlkZW50aWZpZXJzRnJvbSwgcmVzb2x2ZU9yQ3JlYXRlSWRlbnRpdHkgfTsK
B64
node --check "$APP/lib/waidentity.js" && echo "   lib syntax OK"

echo "==> migrate: WhatsApp module schema (as app DB user, idempotent)"
node <<'NODE'
require('dotenv').config();
const crypto = require('crypto');
const { Pool } = require('pg');
const pool = new Pool({ host:process.env.DB_HOST, port:process.env.DB_PORT, database:process.env.DB_NAME, user:process.env.DB_USER, password:process.env.DB_PASS, max:4 });
const q = (s,p)=>pool.query(s,p);
(async()=>{
  // identities
  await q(`CREATE TABLE IF NOT EXISTS whatsapp_identities(
    id serial PRIMARY KEY, canonical_lid text, current_phone_e164 text,
    current_phone_verified boolean NOT NULL DEFAULT false, phone_source text,
    status text NOT NULL DEFAULT 'ACTIVE',
    first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS wa_identity_lid_uidx ON whatsapp_identities(canonical_lid) WHERE canonical_lid IS NOT NULL`);
  // aliases
  await q(`CREATE TABLE IF NOT EXISTS whatsapp_identity_aliases(
    id serial PRIMARY KEY,
    whatsapp_identity_id integer NOT NULL REFERENCES whatsapp_identities(id) ON DELETE CASCADE,
    identifier_type text NOT NULL, identifier_value text NOT NULL, normalized_value text NOT NULL,
    first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz NOT NULL DEFAULT now(),
    is_active boolean NOT NULL DEFAULT true)`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS wa_alias_type_norm_uidx ON whatsapp_identity_aliases(identifier_type, normalized_value)`);
  await q(`CREATE INDEX IF NOT EXISTS wa_alias_identity_idx ON whatsapp_identity_aliases(whatsapp_identity_id)`);
  // customer <-> identity links
  await q(`CREATE TABLE IF NOT EXISTS customer_whatsapp_links(
    id serial PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    whatsapp_identity_id integer NOT NULL REFERENCES whatsapp_identities(id) ON DELETE CASCADE,
    is_primary boolean NOT NULL DEFAULT true, status text NOT NULL DEFAULT 'ACTIVE',
    verified_at timestamptz, linked_at timestamptz NOT NULL DEFAULT now(), unlinked_at timestamptz,
    link_reason text, created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS cwl_active_identity_uidx ON customer_whatsapp_links(whatsapp_identity_id) WHERE status='ACTIVE'`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS cwl_active_primary_uidx ON customer_whatsapp_links(customer_id) WHERE status='ACTIVE' AND is_primary=true`);
  await q(`CREATE INDEX IF NOT EXISTS cwl_customer_idx ON customer_whatsapp_links(customer_id)`);
  // verification sessions
  await q(`CREATE TABLE IF NOT EXISTS whatsapp_verification_sessions(
    id serial PRIMARY KEY, customer_id integer NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    token_hash text NOT NULL, display_code text NOT NULL, purpose text NOT NULL DEFAULT 'ACCOUNT_VERIFY',
    status text NOT NULL DEFAULT 'PENDING', expires_at timestamptz NOT NULL, completed_at timestamptz,
    whatsapp_identity_id integer REFERENCES whatsapp_identities(id) ON DELETE SET NULL,
    requested_ip text, requested_user_agent text, attempts integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS wvs_code_uidx ON whatsapp_verification_sessions(display_code) WHERE status='PENDING'`);
  await q(`CREATE INDEX IF NOT EXISTS wvs_customer_idx ON whatsapp_verification_sessions(customer_id, status)`);
  // phone history
  await q(`CREATE TABLE IF NOT EXISTS whatsapp_phone_history(
    id serial PRIMARY KEY, whatsapp_identity_id integer NOT NULL REFERENCES whatsapp_identities(id) ON DELETE CASCADE,
    phone_e164 text NOT NULL, phone_source text, verified boolean NOT NULL DEFAULT false,
    valid_from timestamptz NOT NULL DEFAULT now(), valid_until timestamptz, change_reason text,
    created_at timestamptz NOT NULL DEFAULT now())`);
  // trial claims (anti-abuse heart)
  await q(`CREATE TABLE IF NOT EXISTS trial_claims(
    id serial PRIMARY KEY, customer_id integer NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    whatsapp_identity_id integer REFERENCES whatsapp_identities(id) ON DELETE SET NULL,
    trial_type text NOT NULL, claimed_at timestamptz NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'CLAIMED', ip text, metadata jsonb,
    created_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS trial_claims_identity_type_uidx ON trial_claims(whatsapp_identity_id, trial_type) WHERE whatsapp_identity_id IS NOT NULL`);
  await q(`CREATE INDEX IF NOT EXISTS trial_claims_customer_idx ON trial_claims(customer_id)`);
  // notification outbox + delivery
  await q(`CREATE TABLE IF NOT EXISTS wa_notifications(
    id serial PRIMARY KEY, customer_id integer REFERENCES customers(id) ON DELETE SET NULL,
    order_id integer, channel text NOT NULL DEFAULT 'whatsapp',
    destination_identity_id integer REFERENCES whatsapp_identities(id) ON DELETE SET NULL,
    destination_phone text, template_key text NOT NULL, vars jsonb,
    status text NOT NULL DEFAULT 'QUEUED', attempts integer NOT NULL DEFAULT 0, last_error text,
    provider_message_id text, idempotency_key text,
    queued_at timestamptz NOT NULL DEFAULT now(), sent_at timestamptz, delivered_at timestamptz, failed_at timestamptz)`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS wa_notif_idem_uidx ON wa_notifications(idempotency_key) WHERE idempotency_key IS NOT NULL`);
  await q(`CREATE INDEX IF NOT EXISTS wa_notif_status_idx ON wa_notifications(status, queued_at)`);
  // audit log
  await q(`CREATE TABLE IF NOT EXISTS wa_audit_log(
    id serial PRIMARY KEY, event text NOT NULL, customer_id integer, identity_id integer,
    actor text, ip text, user_agent text, old_value jsonb, new_value jsonb, reason text,
    created_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE INDEX IF NOT EXISTS wa_audit_customer_idx ON wa_audit_log(customer_id, created_at)`);
  // customers: ref_code + marketing consent
  await q(`ALTER TABLE customers ADD COLUMN IF NOT EXISTS ref_code text`);
  await q(`ALTER TABLE customers ADD COLUMN IF NOT EXISTS wa_marketing_consent boolean NOT NULL DEFAULT false`);
  await q(`ALTER TABLE customers ADD COLUMN IF NOT EXISTS wa_marketing_consent_at timestamptz`);
  await q(`CREATE UNIQUE INDEX IF NOT EXISTS customers_ref_uidx ON customers(ref_code) WHERE ref_code IS NOT NULL`);
  // backfill ref_code
  const AL='0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  const genRef=()=>{ let s=''; const b=crypto.randomBytes(5); for(let i=0;i<5;i++) s+=AL[b[i]%32]; return 'GX-'+s; };
  const need=(await q(`SELECT id FROM customers WHERE ref_code IS NULL`)).rows;
  for(const r of need){ for(let t=0;t<6;t++){ try{ await q(`UPDATE customers SET ref_code=$1 WHERE id=$2`,[genRef(),r.id]); break; }catch(e){ if(t===5) throw e; } } }
  console.log('   ref_code backfilled for '+need.length+' customer(s)');
  // namespaced settings + templates
  await q(`CREATE TABLE IF NOT EXISTS wa_settings(key text PRIMARY KEY, value text, updated_at timestamptz NOT NULL DEFAULT now())`);
  await q(`CREATE TABLE IF NOT EXISTS wa_templates(key text PRIMARY KEY, body text, updated_at timestamptz NOT NULL DEFAULT now())`);
  const secret = crypto.randomBytes(24).toString('hex');
  const defaults = {
    wa_verification_enabled:'1', wa_required_for_trials:'1', wa_required_for_checkout:'0',
    wa_order_notifications_enabled:'1', wa_credentials_delivery_enabled:'1', wa_expiry_notifications_enabled:'1',
    wa_marketing_enabled:'0', wa_verify_token_expiry_minutes:'15', wa_verify_rate_limit:'5',
    wa_unsupported_cooldown:'60', wa_number_change_hold:'0', wa_verify_number:'',
    wa_sales_number:'923141892712', wa_support_number:'923193459191',
    wa_bot_webhook_secret:secret, wa_credentials_mode:'B', wa_bot_status:'DISCONNECTED'
  };
  for(const [k,v] of Object.entries(defaults)) await q(`INSERT INTO wa_settings(key,value) VALUES($1,$2) ON CONFLICT(key) DO NOTHING`,[k,v]);
  const tpl = {
    'whatsapp.verification_success':'✅ Your WhatsApp is now verified for {{site_name}}. (Ref: {{customer_reference}})',
    'whatsapp.order_received':'🧾 {{site_name}}: we received your order {{order_number}}. We will update you here as it progresses.',
    'whatsapp.payment_confirmed':'💰 Payment confirmed for order {{order_number}}. We are processing it now.',
    'whatsapp.order_completed':'🎉 Order {{order_number}} is complete. {{product_name}} is ready.',
    'whatsapp.credentials':'🔐 Your {{product_name}} is ready. View your details securely: {{secure_link}}',
    'whatsapp.subscription_expiry':'⏰ Your {{product_name}} expires on {{expiry_date}}. Reply on our sales number to renew.',
    'whatsapp.number_change':'🔁 Your WhatsApp number on {{site_name}} was changed. If this was not you, contact support immediately.',
    'whatsapp.security_alert':'⚠️ Security alert on your {{site_name}} account: {{detail}}',
    'whatsapp.redirect_support':'This number is for website verification & account security only.\n\nSales: https://wa.me/{{sales_number}}\nSupport: https://wa.me/{{support_number}}\n\nYour ref: {{customer_reference}}'
  };
  for(const [k,b] of Object.entries(tpl)) await q(`INSERT INTO wa_templates(key,body) VALUES($1,$2) ON CONFLICT(key) DO NOTHING`,[k,b]);
  console.log('   wa_settings + wa_templates seeded (webhook secret generated, stored, not printed)');

  // summary counts
  const t = (await q(`SELECT
     (SELECT count(*) FROM whatsapp_identities)::int i,
     (SELECT count(*) FROM wa_settings)::int s,
     (SELECT count(*) FROM wa_templates)::int tp,
     (SELECT count(*) FROM customers WHERE ref_code IS NOT NULL)::int refs`)).rows[0];
  console.log('   tables ready | identities='+t.i+' wa_settings='+t.s+' wa_templates='+t.tp+' customers_with_ref='+t.refs);
  await pool.end();
})().catch(e=>{ console.error('MIGRATION FAIL: '+e.message); process.exit(1); });
NODE

echo "==> verify lib loads + resolver exports"
node -e "const w=require('$APP/lib/waidentity.js'); ['normalizeLid','normalizePhoneE164','classifyIdentifier','resolveOrCreateIdentity'].forEach(f=>{ if(typeof w[f]!=='function') throw new Error('missing '+f); }); console.log('   waidentity exports OK');"

echo "==> health: site still up (no app change, but confirm)"
grep -q '</html>' <<<"$(curl -s -m 15 http://127.0.0.1:3900/ || true)" || { echo "!! home check failed"; false; }
trap - ERR
echo "==> step77 OK — WhatsApp identity foundation in place (invisible). Backup: $BAK"
echo "   Next (2b): Verify-with-WhatsApp UX + challenge + /internal/whatsapp/incoming webhook."
