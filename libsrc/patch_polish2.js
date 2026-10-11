'use strict';
/* Admin polish (batch 2): trim AI-sounding helper text in Branding, Site content
   (was "Content"), Announcements and Marketing, and relabel the "Marquee & stats"
   nav item to "Site content" (the page covers numbers, marquee, About and socials).
   Exact-string edits on the live views. Aborts if any anchor is missing (safe). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_polish2.js <ROOT>'); process.exit(1); }

function edit(rel, items) {
  const file = path.join(ROOT, rel); let s = fs.readFileSync(file, 'utf8');
  for (const [find, repl, name] of items) {
    const i = s.indexOf(find);
    if (i < 0) {
      // already applied: removal (empty repl) whose anchor is gone, or non-empty repl present
      if (repl === '' || s.indexOf(repl) >= 0) { console.log('skip (already): ' + rel + ' :: ' + name); continue; }
      throw new Error('ANCHOR MISS: ' + rel + ' :: ' + name);
    }
    if (s.indexOf(find, i + 1) >= 0) throw new Error('ANCHOR NOT UNIQUE: ' + rel + ' :: ' + name);
    s = s.slice(0, i) + repl + s.slice(i + find.length);
    console.log('trimmed: ' + rel + ' :: ' + name);
  }
  fs.writeFileSync(file, s);
}

edit('views/admin/branding.ejs', [
  ['<p class="sub" style="margin-bottom:18px">Upload your real logo and hero banners. Each slot shows the exact size to use.</p>\n', '', 'intro'],
  ['Transparent PNG or SVG works best. Shown in the header and footer. Recommended size: <b>240 × 64 px</b> (wide) — or any transparent logo; it scales to fit.', 'Recommended: <b>240 × 64 px</b> transparent PNG or SVG.', 'logo hint'],
  ['Each category has a <b>desktop</b> and a <b>mobile</b> banner. The site shows the right one per device automatically.', 'A <b>desktop</b> and <b>mobile</b> banner per category.', 'banner hint']
]);

edit('views/admin/content.ejs', [
  ["<%- include('_shell_top', { active:'content', title:'Content' }) %>", "<%- include('_shell_top', { active:'content', title:'Site content' }) %>", 'title'],
  ['<p class="sub" style="margin-bottom:18px">Edit the homepage numbers, the marquee strip and your About Us page.</p>\n', '', 'intro'],
  ['Shown in the stats band and the reviews block. "Orders delivered" never drops below 50,000.', 'Shown in the homepage stats band.', 'numbers hint'],
  ['Your About page intro. Plain text works (line breaks are kept); simple HTML like &lt;b&gt;, &lt;br&gt; and &lt;a&gt; is allowed. Leave empty to show the default text.', 'Plain text or simple HTML (&lt;b&gt;, &lt;br&gt;, &lt;a&gt;). Empty shows the default.', 'about hint'],
  ['Paste your social profile links — one per line. The footer shows the right icon for each automatically (Instagram, Facebook, Telegram, YouTube, TikTok, X, etc.).', 'One profile link per line — the footer picks the right icon automatically.', 'social hint']
]);

edit('views/admin/announcements.ejs', [
  ['<p class="sub">Post news or a promo to your customers. Target everyone, or only buyers of one product. Optionally push it to their WhatsApp (verified numbers only).</p>', '<p class="sub">Post news or a promo to your customers — on their dashboard, and optionally WhatsApp.</p>', 'intro']
]);

edit('views/admin/marketing.ejs', [
  ['<p class="sub">Send a promotional email to your customers. Order &amp; account emails are separate and unaffected. Every promo includes a one-click unsubscribe link.</p>', '<p class="sub">Send a promotional email to your customers, with a one-click unsubscribe.</p>', 'intro']
]);

edit('views/admin/_shell_top.ejs', [
  ['>Marquee &amp; stats</a>', '>Site content</a>', 'nav label']
]);

console.log('POLISH2 OK');
