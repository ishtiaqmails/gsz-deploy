'use strict';
/* Blog button fix (root cause, consolidated).
   Problem: `.cs-article a` (specificity 0,1,1) sets link color + underline and OUT-RANKS the
   button variant classes `.cs-btn-primary` etc. (0,1,0), so published buttons get cyan link text
   + underline. A prior patch only killed the underline (.cs-article a.cs-btn{border-bottom:0}),
   not the color.
   Fix: exclude buttons from the article-link rule with :not(.cs-btn) — one change fixes color AND
   underline; the redundant border-bottom reset is removed. Cache-bust content.css so browsers
   refetch (this is why it "came back"). */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_blogbtn.js <ROOT>'); process.exit(1); }
const CSS = path.join(ROOT, 'public/css/content.css');
const ART = path.join(ROOT, 'views/content_article.ejs');
const LST = path.join(ROOT, 'views/content_list.ejs');

function editOnce(file, name, find, replace, optional) {
  let s = fs.readFileSync(file, 'utf8');
  if (s.indexOf(replace) >= 0 && s.indexOf(find) < 0) { console.log('skip (already): ' + name); return; }
  const i = s.indexOf(find);
  if (i < 0) { if (optional) { console.log('skip (not found): ' + name); return; } throw new Error('ANCHOR MISS: ' + name); }
  if (s.indexOf(find, i + find.length) >= 0 && name.indexOf('cachebust') < 0) throw new Error('ANCHOR NOT UNIQUE: ' + name);
  fs.writeFileSync(file, s.split(find).join(replace));
  console.log('patched: ' + name);
}

// 1) article-link color/underline rule -> exclude buttons
editOnce(CSS, 'css:link-rule',
  '.cs-article a{color:var(--c,#28d6ff);text-decoration:none;border-bottom:1px solid rgba(40,214,255,.3)}',
  '.cs-article a:not(.cs-btn){color:var(--c,#28d6ff);text-decoration:none;border-bottom:1px solid rgba(40,214,255,.3)}');
// 2) hover rule -> exclude buttons
editOnce(CSS, 'css:link-hover',
  '.cs-article a:hover{border-bottom-color:var(--c,#28d6ff)}',
  '.cs-article a:not(.cs-btn):hover{border-bottom-color:var(--c,#28d6ff)}');
// 3) remove now-redundant underline reset (kept minimal: blank the rule)
editOnce(CSS, 'css:drop-redundant',
  '.cs-article a.cs-btn{border-bottom:0}\n', '', true);
editOnce(CSS, 'css:drop-redundant-nonl',
  '.cs-article a.cs-btn{border-bottom:0}', '', true);

// 4) cache-bust so browsers refetch the corrected CSS
editOnce(ART, 'cachebust:article', 'content.css?v=2', 'content.css?v=3', true);
editOnce(LST, 'cachebust:list', 'content.css?v=2', 'content.css?v=3', true);

console.log('BLOGBTN PATCH OK');
