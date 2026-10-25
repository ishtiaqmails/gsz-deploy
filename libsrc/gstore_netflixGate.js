'use strict';
/*
 * Netflix plan-gating — PURE, default-deny filter.
 * The NEW portal classifies accurately and separates types, so refineType maps the portal
 * type set directly to the store vocabulary (legacy household-subject split kept as fallback).
 *   signin_code / verification_code -> signin_code (numeric code, Phone)
 *   temporary_access                -> travel_code (numeric code, Phone)
 *   household                       -> household_update (tap-link, TV)
 *   password_reset                  -> password_reset (tap-link, Full)
 *   password_changed / other        -> other (Full)
 *   new_signin (new-device alert)   -> Full-only (portal also marks it owner_only, so it's
 *                                      dropped upstream; kept Full-only as defence-in-depth)
 * Store-side vocabulary: signin_code, new_signin, travel_code, household_update, password_reset, other.
 */

// New portal type -> store vocabulary.
var TYPE_MAP = {
  signin_code: 'signin_code',
  verification_code: 'signin_code',
  new_signin: 'new_signin',
  temporary_access: 'travel_code',
  household: 'household_update',
  password_reset: 'password_reset',
  password_changed: 'other',
  other: 'other'
};

function refineType(email) {
  var t = email && email.type;
  if (TYPE_MAP[t]) return TYPE_MAP[t];
  if (t !== 'household') return t; // already in store vocabulary (or unknown)
  // Legacy fallback: old portal lumped travel into 'household' — split by subject.
  var subj = String((email && email.subject) || '').toLowerCase();
  if (/update household|household.*update|verify.*tv|tv.*verify|confirm.*device|approve.*tv|watch on (your )?tv/.test(subj)) return 'household_update';
  if (/temporary access|temporarily|travel|travelling|traveling|on the go|away from home/.test(subj)) return 'travel_code';
  return 'household_update';
}

// Per-tier allow-lists over the store vocabulary.
// Phone: numeric sign-in + travel codes only (no password-change / household links).
// TV: + household_update (device-confirm tap-link).
// Full: + new_signin + password_reset + other.
var PLAN_ALLOW = {
  phone: ['signin_code', 'travel_code'],
  tv:    ['signin_code', 'travel_code', 'household_update'],
  full:  ['signin_code', 'travel_code', 'household_update', 'new_signin', 'password_reset', 'other']
};

function tierForPlan(planLabel) {
  var s = String(planLabel || '').toLowerCase();
  if (/full|complete|whole|entire|mailbox|all\s*access/.test(s)) return 'full';
  if (/tv|television|screen|big\s*screen|smart\s*tv/.test(s))     return 'tv';
  if (/phone|mobile|cell/.test(s))                                return 'phone';
  return 'phone'; // default-deny: unknown → least access
}

function allowedTypesFor(planLabel, explicitAllowed) {
  if (Array.isArray(explicitAllowed) && explicitAllowed.length) {
    return explicitAllowed.filter(function (t) { return typeof t === 'string' && t; });
  }
  return PLAN_ALLOW[tierForPlan(planLabel)] || PLAN_ALLOW.phone;
}

// THE GATE. Refines each email's type first, then keeps only allowed types.
function filterEmails(emails, allowedTypes) {
  var allow = {};
  (allowedTypes || []).forEach(function (t) { allow[t] = true; });
  return (emails || []).map(function (m) {
    if (!m) return null;
    return Object.assign({}, m, { type: refineType(m) });
  }).filter(function (m) {
    return m && typeof m.type === 'string' && allow[m.type] === true;
  });
}

module.exports = { PLAN_ALLOW, tierForPlan, allowedTypesFor, filterEmails, refineType };
