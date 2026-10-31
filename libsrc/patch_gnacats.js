'use strict';
/* GNACATS_v1 — make the mobile Store sheet (app_nav.ejs gnaStoreSheet) render ALL categories from
   live `cats` instead of 5 hardcoded <a>. Keeps per-category icons for known slugs, a clean grid
   icon for any new one. Also lifts the slice(0,6) cap on the store_bottom drawer categories.
   Gated on the 'gna-cat-dyn' marker for idempotency; split/join; throws on a miss (step restores). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2] || '/opt/gsz';

const F = 'views/partials/app_nav.ejs';
// EXACT hardcoded lines (verbatim from the live file).
const L_ENT = '  <a class="gna-cat" href="/category/entertainment"><span class="gna-ci"><svg viewBox="0 0 24 24"><polygon points="10 8 16 12 10 16 10 8"/><rect x="2.5" y="4" width="19" height="16" rx="2.5"/></svg></span><span><b>Entertainment</b><small>Netflix, Disney+, Prime &amp; more</small></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>';
const L_IPTV = '  <a class="gna-cat" href="/category/iptv"><span class="gna-ci"><svg viewBox="0 0 24 24"><rect x="2.5" y="4.5" width="19" height="13" rx="2"/><path d="M8 21h8M12 17.5V21"/></svg></span><span><b>IPTV services</b><small>Live channels &amp; flexible plans</small></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>';
const L_VPN = '  <a class="gna-cat" href="/category/vpns"><span class="gna-ci"><svg viewBox="0 0 24 24"><path d="M12 2 4 5v6c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V5z"/></svg></span><span><b>VPNs</b><small>Private &amp; secure browsing</small></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>';
const L_TOOLS = '  <a class="gna-cat" href="/category/tools"><span class="gna-ci"><svg viewBox="0 0 24 24"><path d="M14.7 6.3a4 4 0 0 1-5.4 5.4L4 17v3h3l5.3-5.3a4 4 0 0 0 5.4-5.4l-2.3 2.3-2-2z"/></svg></span><span><b>Tools</b><small>AI, design &amp; productivity</small></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>';
const L_PLAY = '  <a class="gna-cat" href="/category/players"><span class="gna-ci"><svg viewBox="0 0 24 24"><rect x="6" y="2.5" width="12" height="19" rx="2.5"/><path d="M11 18.5h2"/></svg></span><span><b>IPTV Players</b><small>Activate your player app</small></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>';

const LOOP =
'  <% var _ci={' +
"'entertainment':'<polygon points=\"10 8 16 12 10 16 10 8\"/><rect x=\"2.5\" y=\"4\" width=\"19\" height=\"16\" rx=\"2.5\"/>'," +
"'iptv':'<rect x=\"2.5\" y=\"4.5\" width=\"19\" height=\"13\" rx=\"2\"/><path d=\"M8 21h8M12 17.5V21\"/>'," +
"'vpns':'<path d=\"M12 2 4 5v6c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V5z\"/>'," +
"'tools':'<path d=\"M14.7 6.3a4 4 0 0 1-5.4 5.4L4 17v3h3l5.3-5.3a4 4 0 0 0 5.4-5.4l-2.3 2.3-2-2z\"/>'," +
"'players':'<rect x=\"6\" y=\"2.5\" width=\"12\" height=\"19\" rx=\"2.5\"/><path d=\"M11 18.5h2\"/>'," +
"'windows-activations-keys':'<circle cx=\"7.5\" cy=\"15.5\" r=\"4.5\"/><path d=\"m10.7 12.3 9.3-9.3\"/><path d=\"m16 7 3 3\"/>'" +
'};\n' +
'     var _cs={' +
"'entertainment':'Netflix, Disney+, Prime & more','iptv':'Live channels & flexible plans','vpns':'Private & secure browsing','tools':'AI, design & productivity','players':'Activate your player app','windows-activations-keys':'Windows, Office & keys'" +
'};\n' +
'     var _cdef=\'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>\';\n' +
'     (typeof cats!==\'undefined\'&&cats?cats:[]).forEach(function(c){ var _ic=_ci[c.slug]||_cdef; var _sub=_cs[c.slug]||c.tagline||c.subtitle||c.blurb||\'\'; %>\n' +
'  <a class="gna-cat gna-cat-dyn" href="/category/<%= c.slug %>"><span class="gna-ci"><svg viewBox="0 0 24 24"><%- _ic %></svg></span><span><b><%= c.name %></b><% if(_sub){ %><small><%= _sub %></small><% } %></span><span class="gna-ar"><svg viewBox="0 0 24 24" width="16" height="16" style="stroke:currentColor;fill:none;stroke-width:2"><path d="m9 18 6-6-6-6"/></svg></span></a>\n' +
'  <% }); %>';

let s = fs.readFileSync(path.join(ROOT, F), 'utf8');
let applied = 0;
if (s.indexOf('gna-cat-dyn') >= 0) {
  console.log('GNACATS app_nav: already applied');
} else {
  for (const [name, line] of [['Entertainment', L_ENT], ['IPTV', L_IPTV], ['VPN', L_VPN], ['Tools', L_TOOLS], ['Players', L_PLAY]]) {
    if (s.indexOf(line) < 0) throw new Error('ANCHOR MISSING in ' + F + ': ' + name + ' hardcoded <a>');
  }
  s = s.split(L_ENT).join(LOOP);           // first one becomes the loop
  for (const line of [L_IPTV, L_VPN, L_TOOLS, L_PLAY]) s = s.split(line + '\n').join('').split(line).join('');
  fs.writeFileSync(path.join(ROOT, F), s);
  applied++;
}

// --- store_bottom.ejs: lift the slice(0,6) cap on the drawer categories ---
const F2 = 'views/partials/store_bottom.ejs';
const B_OLD = "<% cats.slice(0,6).forEach(function(c){ %><a href=\"/category/<%= c.slug %>\"><%= c.name %></a><% }); %>";
const B_NEU = "<% cats.forEach(function(c){ %><a href=\"/category/<%= c.slug %>\"><%= c.name %></a><% }); %>";
let s2 = fs.readFileSync(path.join(ROOT, F2), 'utf8');
if (s2.indexOf(B_NEU) >= 0 && s2.indexOf(B_OLD) < 0) {
  console.log('GNACATS store_bottom: already applied');
} else {
  if (s2.indexOf(B_OLD) < 0) throw new Error('ANCHOR MISSING in ' + F2 + ': cats.slice(0,6) drawer');
  s2 = s2.split(B_OLD).join(B_NEU);
  fs.writeFileSync(path.join(ROOT, F2), s2);
  applied++;
}

console.log('GNACATS_v1 applied=' + applied);
