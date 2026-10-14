'use strict';
/* Premium voice for the on-site support chat (lib/supportbot.js).
   Rewrites greeting/welcome/bye/handoff/track/resend/issue copy and replaces the two
   jargon button labels with plain human words. Display-only strings + action labels
   (handlers key on tool:, not label). Single-line anchors -> CRLF/indent-safe. Idempotent. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_supportbot.js <ROOT>'); process.exit(1); }
const SB = path.join(ROOT, 'lib/supportbot.js');

let s = fs.readFileSync(SB, 'utf8');
let applied = 0, skipped = 0;
function sub(name, find, replace) {
  if (s.indexOf(replace) >= 0 && s.indexOf(find) < 0) { console.log('skip (already): ' + name); skipped++; return; }
  const i = s.indexOf(find);
  if (i < 0) { console.log('MISS (left as-is): ' + name); return; }
  if (s.indexOf(find, i + find.length) >= 0) { throw new Error('ANCHOR NOT UNIQUE: ' + name); }
  s = s.slice(0, i) + replace + s.slice(i + find.length);
  console.log('patched: ' + name); applied++;
}

// 1) greeting (empty message)
sub('greeting',
  "'Hi! Ask me about any product, price, plan, delivery, or your order.'",
  "'Hi 👋 I\\'m here to help. Ask me anything — products, prices, plans, delivery, or your order.'");
// 2) welcome (two fragments around site name)
sub('welcome-a', "'Hey! 👋 Welcome to '", "'Hey 👋 Welcome to '");
sub('welcome-b',
  "'. Ask me about any product — prices, plans, delivery time, or help with an order.'",
  "' — glad you\\'re here. Ask about any product: prices, plans, delivery time, or help with an existing order.'");
// 3) bye
sub('bye',
  "'Take care! We\\'re here 24/7 whenever you need us. 💙'",
  "'Take care! 💙 We\\'re here whenever you need us — just message anytime.'");
// 4) whatsapp handoff
sub('handoff',
  "'Of course! 💬 Tap below to chat with our team on WhatsApp — we usually reply quickly.'",
  "'Of course 💬 Tap below to reach our team on WhatsApp — we\\'ll get right back to you.'");
// 5) track order (no number given)
sub('track',
  "'Happy to track your order — what\\'s your order number? It looks like GSZ-1234.'",
  "'Happy to help you track it — what\\'s your order number? It looks like GSZ-1234.'");
// 6) resend details (drop 'Get Access' jargon in the sentence)
sub('resend',
  "'Happy to resend your code or link. Tap Get Access to send it to yourself instantly'",
  "'Happy to resend your details — tap below and I\\'ll send them to you right away'");
// 7) resend button label
sub('label-access', "label: 'Get Access'", "label: 'Send me my details'");
// 8) issue/claim sentence
sub('issue',
  "' — let\\'s get it sorted. You can open a claim/replacement in a tap, or message us on WhatsApp and we\\'ll jump on it.'",
  "' — let\\'s get it sorted. You can report the problem in a tap, or message us on WhatsApp and we\\'ll jump on it.'");
// 9) claim button label
sub('label-claim', "label: 'Open a Claim'", "label: 'Report a problem'");
// 10) trial button label
sub('label-trial', "label: 'Get a Free Trial'", "label: 'Start a free trial'");

fs.writeFileSync(SB, s);
console.log('SUPPORTBOT PATCH OK (applied=' + applied + ', skipped=' + skipped + ')');
