'use strict';
/* Premium delivery composer (website-side).
   Turns the bot's structured `fields` + the GSZ order into the website's own premium WhatsApp
   message(s). Pure + fail-safe: returns { main, followup } (followup may be ''). If fields are
   missing/empty, returns { main:'', followup:'' } so the caller can fall back to the raw text. */

function esc(v) { return String(v == null ? '' : v).trim(); }
const RULE = '━━━━━━━━━━━━━━'; // ━×14
function sectionTitle(t) { return '━━━  *' + t + '*  ━━━'; }

function fmtDate(d) {
  try { return new Date(d || Date.now()).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' }); }
  catch (e) { return ''; }
}

// compose(order, fields, opts) -> { main, followup }
// order: { order_no, created_at, product_name, plan_label }
// opts:  { siteName, salesNumber, instructions, warranty }
//   instructions/warranty come from the WEBSITE admin (per product/plan) — NOT from the bot.
//   The bot's own instructions/warranty are ignored (they are written for the bot's customers).
function compose(order, fields, opts) {
  order = order || {}; fields = fields || {}; opts = opts || {};
  const dt = esc(fields.delivery_type) || 'credentials';
  const site = esc(opts.siteName) || 'Galaxy Subz × Zayron';
  const sales = String(opts.salesNumber || '').replace(/[^0-9]/g, '');
  const product = esc(fields.product) || esc(order.product_name);
  const plan = esc(fields.plan) || esc(order.plan_label);
  const expiry = esc(fields.expiry);
  const orderNo = esc(order.order_no);
  const isInvite = dt === 'vendor_invite';
  const isTrial = !!opts.trial;
  const durationLabel = esc(opts.durationLabel);
  const versionLabel = esc(opts.versionLabel);

  // header
  const L = [];
  L.push(RULE);
  L.push(isTrial ? '🎁 *FREE TRIAL READY*' : (isInvite ? '✅ *INVITE SENT*' : '✅ *ORDER DELIVERED*'));
  L.push('_' + site + '_');
  L.push(RULE);
  L.push('');
  if (product) L.push('📦 *' + product + '*');
  if (isTrial) {
    L.push('🎯 Trial  ·  ' + (durationLabel || plan || 'Trial'));
    if (expiry) L.push('📆 Expires  ·  ' + expiry);
  } else {
    if (orderNo) L.push('🧾 Order  ·  ' + orderNo);
    L.push('📅 ' + (isInvite ? 'Sent' : 'Purchased') + '  ·  ' + fmtDate(order.created_at));
    if (plan) L.push('⏳ Plan  ·  ' + plan + (versionLabel ? ' — ' + versionLabel : ''));
    else if (versionLabel) L.push('⏳ Plan  ·  ' + versionLabel);
    if (expiry) L.push('📆 Expires  ·  ' + expiry);
  }
  L.push('');

  // body by type
  const details = Array.isArray(fields.details) ? fields.details.filter(function (d) {
    const lb = esc(d && d.label).toLowerCase();
    return esc(d && d.value) && lb !== 'support'; // drop the bot's support line; website adds its own
  }) : [];

  if (dt === 'vendor_invite') {
    const boxes = (fields.invite && Array.isArray(fields.invite.inboxes)) ? fields.invite.inboxes.filter(Boolean) : [];
    L.push(sectionTitle('CHECK YOUR INBOX'));
    boxes.forEach(function (b) { L.push('📧 ' + esc(b)); });
    L.push('');
    L.push('Open the invite from your inbox — check spam/junk too.');
    L.push(RULE);
  } else if (dt === 'player_activation') {
    const acts = Array.isArray(fields.activations) ? fields.activations : [];
    L.push(sectionTitle('ACTIVATED'));
    acts.forEach(function (a) {
      const mac = esc(a && a.mac); const pl = esc(a && a.plan); const ex = esc(a && a.expiry);
      L.push('• ' + mac + (pl ? ' — ' + pl : '') + (ex ? ' (exp ' + ex + ')' : ''));
    });
    L.push(RULE);
  } else {
    // credentials / portal / iptv / other -> labelled login block
    L.push(sectionTitle(dt === 'iptv' ? 'YOUR LINE' : 'YOUR LOGIN'));
    details.forEach(function (d) { L.push(esc(d.label) + ':  ' + esc(d.value)); });
    L.push(RULE);
    if (dt === 'iptv') {
      const players = Array.isArray(fields.players) ? fields.players : [];
      if (players.length) {
        L.push('');
        L.push('📺 *WATCH ON*');
        players.forEach(function (p) { L.push('• ' + esc(p && p.platform) + ' — ' + esc(p && p.url)); });
        L.push(RULE);
      }
    }
  }

  // footer
  L.push('');
  if (isTrial) {
    const up = esc(opts.siteUrl);
    if (up) L.push('🚀 Upgrade to full access: ' + up);
    if (sales) L.push('💬 Questions? wa.me/' + sales);
    L.push('Thank you for trying us.');
  } else {
    if (sales) L.push('💬 Need help? wa.me/' + sales);
    L.push('Thank you for choosing us.');
  }
  const main = L.join('\n');

  // Clean credentials block for the website admin (mirrors what the customer received).
  let credentials = '';
  if (details.length) {
    const credLines = [];
    if (versionLabel) credLines.push('Version: ' + versionLabel);
    details.forEach(function (d) { credLines.push(esc(d.label) + ': ' + esc(d.value)); });
    if (expiry) credLines.push('Expiry: ' + expiry);
    credentials = credLines.join('\n');
  }

  // follow-up: How-to-Use + Warranty — ALWAYS from the website admin (opts), never the bot.
  let instr = opts.instructions;
  if (typeof instr === 'string') instr = instr.split(/\r?\n/);
  instr = Array.isArray(instr) ? instr.map(esc).filter(Boolean) : [];
  const warr = esc(opts.warranty);
  let followup = '';
  if (instr.length || warr) {
    const F = [];
    F.push(RULE);
    F.push('📋 *' + (product || 'Your order') + '*');
    F.push('_Instructions & Warranty_');
    F.push(RULE);
    if (instr.length) { instr.forEach(function (x) { F.push('• ' + x); }); }
    if (warr) { F.push(''); F.push('🛡️ *Warranty:* ' + warr); }
    if (sales) { F.push(''); F.push('💬 Any issue? wa.me/' + sales); }
    followup = F.join('\n');
  }

  return { main: main, followup: followup, credentials: credentials };
}

module.exports = { compose };
