'use strict';
/* Netflix plan -> tier gating. Phone < TV < Full. The NEW portal classifier is
   authoritative on `type`, so refineType maps the portal type set directly to our
   rtype vocabulary (with a legacy subject-based fallback for any unmapped type).
   Default-deny: an email shows only if its refined type is allowed for the plan's tier. */
const PLAN_ALLOW = {
  phone: ['signin_code', 'new_signin', 'travel_code'],
  tv:    ['signin_code', 'new_signin', 'travel_code', 'household_update'],
  full:  ['signin_code', 'new_signin', 'travel_code', 'household_update', 'password_reset', 'other']
};

// New portal type -> our rtype vocabulary.
const TYPE_MAP = {
  signin_code: 'signin_code',
  verification_code: 'signin_code',
  new_signin: 'new_signin',
  temporary_access: 'travel_code',
  household: 'household_update',
  password_reset: 'password_reset',
  password_changed: 'other',
  other: 'other'
};

function tierForPlan(label) {
  const s = String(label || '').toLowerCase();
  if (s.indexOf('full') >= 0) return 'full';
  if (s.indexOf('tv') >= 0) return 'tv';
  return 'phone'; // phone / laptop / unknown -> least privilege
}

function refineType(email) {
  const t = String(email && email.type || '').toLowerCase();
  if (TYPE_MAP[t]) return TYPE_MAP[t];
  if (['signin_code', 'new_signin', 'travel_code', 'household_update', 'password_reset'].indexOf(t) >= 0) return t;
  // Legacy fallback: re-read the subject (old portal didn't always classify).
  const subj = String(email && email.subject || '').toLowerCase();
  const isTravel = /(temporary access|travel|travelling|on the go|away from home)/.test(subj);
  const isHousehold = /(update household|verify tv|confirm device|approve tv|watch on tv|household)/.test(subj);
  if (t === 'household' || isTravel || isHousehold) { return (isTravel && !isHousehold) ? 'travel_code' : 'household_update'; }
  if (/reset.*password|password.*reset/.test(subj)) return 'password_reset';
  if (/sign-?in code|verification code|your code|code is|enter this code/.test(subj)) return 'signin_code';
  return 'other';
}

function allowedTypesFor(label) { return PLAN_ALLOW[tierForPlan(label)] || PLAN_ALLOW.phone; }
function filterEmails(emails, label) {
  const allow = allowedTypesFor(label);
  return (Array.isArray(emails) ? emails : [])
    .map(e => Object.assign({}, e, { rtype: refineType(e) }))
    .filter(e => allow.indexOf(e.rtype) >= 0);
}

module.exports = { PLAN_ALLOW, tierForPlan, refineType, allowedTypesFor, filterEmails };
