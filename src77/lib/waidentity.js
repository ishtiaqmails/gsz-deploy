'use strict';
/* WhatsApp identity engine — normalization + alias-based resolution.
   The LID is the canonical persistent identity; phone numbers are contact
   data that can change. One identity may surface under several identifiers
   (LID, PN JID, phone). This module resolves them to a single identity row
   and never creates duplicates when the same identity appears two ways.
   The normalize and classify helpers have no DB deps and are unit-tested. */

// ---- pure normalization helpers ----
function normalizeLid(raw) {
  if (!raw) return null;
  const s = String(raw).trim().toLowerCase();
  const m = s.match(/(\d{5,})(?:[:@]|$)/); // digits before @lid / :device / end
  return m ? m[1] : (/^\d{5,}$/.test(s) ? s : null);
}
function normalizePhoneE164(raw) {
  if (!raw) return null;
  const low = String(raw).toLowerCase();
  // A LID / group / broadcast is NOT a phone number — never fabricate one from it.
  if (low.indexOf('@lid') >= 0 || low.indexOf('@g.us') >= 0 || low.indexOf('@broadcast') >= 0 || low.indexOf('@newsletter') >= 0) return null;
  let s = String(raw).trim();
  s = s.split('@')[0];                 // drop @s.whatsapp.net etc.
  s = s.replace(/[^\d+]/g, '');         // keep digits and +
  s = s.replace(/^00/, '');             // intl 00 prefix
  s = s.replace(/[^\d]/g, '');          // digits only now
  if (s.length < 8 || s.length > 15) return null;
  return '+' + s;
}
function normalizeJid(raw) {
  if (!raw) return null;
  return String(raw).trim().toLowerCase();
}
function classifyIdentifier(raw) {
  const s = normalizeJid(raw);
  if (!s) return 'UNKNOWN';
  if (s.endsWith('@lid')) return 'LID';
  if (s.endsWith('@s.whatsapp.net') || s.endsWith('@c.us')) return 'PN_JID';
  if (/^\+?\d{8,15}$/.test(s)) return 'PHONE_E164';
  if (/^\d{5,}$/.test(s)) return 'LID';
  return 'UNKNOWN';
}

// Build the list of {identifier_type, identifier_value, normalized_value} from a raw event.
function identifiersFrom(parts) {
  const out = [];
  const push = (type, value, norm) => { if (value && norm) out.push({ identifier_type: type, identifier_value: String(value), normalized_value: norm }); };
  const isPn = j => { const s = String(j || '').toLowerCase(); return s.endsWith('@s.whatsapp.net') || s.endsWith('@c.us'); };
  if (parts.lid) push('LID', parts.lid, normalizeLid(parts.lid));
  // Only accept a PN JID that really is one — a LID passed in as pnJid is ignored.
  if (parts.pnJid && isPn(parts.pnJid)) push('PN_JID', parts.pnJid, normalizeJid(parts.pnJid));
  // Phone comes only from an explicit phone or a real PN JID — never from a LID.
  const phone = parts.phone || (isPn(parts.pnJid) ? parts.pnJid : null);
  const e164 = normalizePhoneE164(phone);
  if (e164) push('PHONE_E164', phone, e164);
  // de-dupe by type+norm
  const seen = {}; return out.filter(x => { const k = x.identifier_type + '|' + x.normalized_value; if (seen[k]) return false; seen[k] = 1; return true; });
}

/* Resolve an incoming WhatsApp event to a single identity row, creating it if
   new. Must be called inside a transaction (pass a connected client `c`).
   Returns { identity, created, idsAdded }. Alias uniqueness on
   (identifier_type, normalized_value) makes concurrent inserts converge. */
async function resolveOrCreateIdentity(c, parts, opts) {
  opts = opts || {};
  const ids = identifiersFrom(parts);
  if (!ids.length) throw new Error('no usable WhatsApp identifiers in event');

  // 1) find an existing identity via any alias
  let identityId = null;
  for (const id of ids) {
    const r = await c.query(
      'SELECT whatsapp_identity_id FROM whatsapp_identity_aliases WHERE identifier_type=$1 AND normalized_value=$2 LIMIT 1',
      [id.identifier_type, id.normalized_value]);
    if (r.rows[0]) { identityId = r.rows[0].whatsapp_identity_id; break; }
  }

  const lid = (ids.find(x => x.identifier_type === 'LID') || {}).normalized_value || null;
  const e164 = (ids.find(x => x.identifier_type === 'PHONE_E164') || {}).normalized_value || null;
  const phoneSource = e164 ? (opts.phoneSource || (parts.phone ? 'USER_SHARED' : 'REMOTE_JID')) : null;
  let created = false;

  // 2) create if none
  if (!identityId) {
    const r = await c.query(
      `INSERT INTO whatsapp_identities(canonical_lid, current_phone_e164, current_phone_verified, phone_source, status, first_seen_at, last_seen_at)
       VALUES($1,$2,$3,$4,'ACTIVE', now(), now()) RETURNING *`,
      [lid, e164, e164 ? !!opts.phoneVerified : false, phoneSource]);
    identityId = r.rows[0].id;
    created = true;
    if (e164) await c.query(
      `INSERT INTO whatsapp_phone_history(whatsapp_identity_id, phone_e164, phone_source, verified, valid_from, change_reason)
       VALUES($1,$2,$3,$4, now(), 'INITIAL_VERIFICATION')`, [identityId, e164, phoneSource, !!opts.phoneVerified]);
  } else {
    await c.query('UPDATE whatsapp_identities SET last_seen_at=now(), updated_at=now() WHERE id=$1', [identityId]);
    // fill canonical_lid / phone if we now learned them and they were missing
    if (lid) await c.query('UPDATE whatsapp_identities SET canonical_lid=COALESCE(canonical_lid,$2) WHERE id=$1', [identityId, lid]);
    if (e164) {
      const cur = (await c.query('SELECT current_phone_e164 FROM whatsapp_identities WHERE id=$1', [identityId])).rows[0];
      if (cur && !cur.current_phone_e164) {
        await c.query('UPDATE whatsapp_identities SET current_phone_e164=$2, phone_source=$3, current_phone_verified=$4 WHERE id=$1',
          [identityId, e164, phoneSource, !!opts.phoneVerified]);
        await c.query(
          `INSERT INTO whatsapp_phone_history(whatsapp_identity_id, phone_e164, phone_source, verified, valid_from, change_reason)
           VALUES($1,$2,$3,$4, now(), 'INITIAL_VERIFICATION')`, [identityId, e164, phoneSource, !!opts.phoneVerified]);
      }
    }
  }

  // 3) upsert aliases (unique on type+normalized converges races onto one identity)
  let idsAdded = 0;
  for (const id of ids) {
    const up = await c.query(
      `INSERT INTO whatsapp_identity_aliases(whatsapp_identity_id, identifier_type, identifier_value, normalized_value, first_seen_at, last_seen_at, is_active)
       VALUES($1,$2,$3,$4, now(), now(), true)
       ON CONFLICT(identifier_type, normalized_value)
       DO UPDATE SET last_seen_at=now(), is_active=true
       RETURNING (xmax=0) AS inserted`,
      [identityId, id.identifier_type, id.identifier_value, id.normalized_value]);
    if (up.rows[0] && up.rows[0].inserted) idsAdded++;
  }

  const identity = (await c.query('SELECT * FROM whatsapp_identities WHERE id=$1', [identityId])).rows[0];
  return { identity, created, idsAdded };
}

module.exports = { normalizeLid, normalizePhoneE164, normalizeJid, classifyIdentifier, identifiersFrom, resolveOrCreateIdentity };
