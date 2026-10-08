'use strict';
/* Content Studio — render normalized blocks to dark-theme HTML that matches the
   storefront (reuses app.css design tokens). Product/category cards pull LIVE data
   via the maps passed in opts (prefetched by the route) — never duplicated in the post. */

function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
function money(pkr) { const n = Math.round(Number(pkr) || 0); return n > 0 ? ('Rs ' + n.toLocaleString('en-US')) : ''; }

// resolve a button destination -> { href, target, rel }
function btnHref(btn, opts) {
  const d = btn.dest || {}; const v = d.value || '';
  let href = '#';
  switch (d.type) {
    case 'product': href = '/product/' + encodeURIComponent(v); break;
    case 'category': href = '/category/' + encodeURIComponent(v); break;
    case 'article': href = '/blog/' + encodeURIComponent(v); break;
    case 'guide': href = '/guides/' + encodeURIComponent(v); break;
    case 'tutorial': href = '/tutorials/' + encodeURIComponent(v); break;
    case 'checkout': href = '/checkout?p=' + encodeURIComponent(v); break;
    case 'whatsapp': {
      const wa = (opts.waNumber || '').replace(/[^0-9]/g, '');
      href = wa ? ('https://wa.me/' + wa + (d.waText ? ('?text=' + encodeURIComponent(d.waText)) : '')) : '#';
      break;
    }
    case 'download': case 'external': case 'custom': href = /^https?:\/\//i.test(v) ? v : ('/' + v.replace(/^\/+/, '')); break;
    default: href = v ? (/^https?:\/\//i.test(v) ? v : ('/' + v.replace(/^\/+/, ''))) : '#';
  }
  // UTM
  if (btn.utm && /^https?:\/\//i.test(href)) {
    const q = Object.keys(btn.utm).filter(function (k) { return /^utm_/.test(k); }).map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(btn.utm[k]); }).join('&');
    if (q) href += (href.indexOf('?') >= 0 ? '&' : '?') + q;
  }
  const external = /^https?:\/\//i.test(href);
  const target = (btn.newTab || external || d.type === 'whatsapp') ? ' target="_blank"' : '';
  const rel = [(external ? 'noopener' : ''), btn.rel].filter(Boolean).join(' ');
  return { href: href, target: target, rel: rel ? (' rel="' + rel + '"') : '', track: btn.track || '' };
}

function renderButton(btn, opts) {
  const h = btnHref(btn, opts);
  const cls = { primary: 'btn btn-primary', dark: 'btn btn-dark', ghost: 'btn btn-ghost', wa: 'btn btn-wa' }[btn.style] || 'btn btn-primary';
  const size = btn.size === 'lg' ? ' btn-lg' : '';
  const dt = btn.track ? (' data-cs-cta="' + esc(btn.track) + '"') : '';
  return '<a class="' + cls + size + '"' + ' href="' + esc(h.href) + '"' + h.target + h.rel + dt + '>' + esc(btn.label) + '</a>';
}

function productCard(p) {
  if (!p) return '';
  const img = p.image ? ('<img class="pimg" loading="lazy" src="/static/img/' + esc(p.image) + '" alt="' + esc(p.name) + '">')
    : ('<div class="pfallback" style="--g1:' + esc(p.g1 || '#2a6cff') + ';--g2:' + esc(p.g2 || '#19c6ee') + '"><span>' + esc(p.name) + '</span></div>');
  const price = p.from > 0 ? ('<div class="pfoot">' + (p.plans > 1 ? '<span class="pfrom">From</span>' : '') + '<span class="pprice">' + esc(money(p.from)) + '</span></div>') : '';
  return '<a class="pcard" href="/product/' + esc(p.slug) + '" data-cs-prod="' + esc(p.slug) + '">' + img +
    '<div class="pbody"><div class="pname">' + esc(p.name) + '</div>' +
    (p.short_desc ? ('<div class="pdesc">' + esc(p.short_desc) + '</div>') : '') + price + '</div></a>';
}

const ICONS = {
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/>',
  tip: '<path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2Z"/>',
  warn: '<path d="M10.3 3.9 2.4 18a2 2 0 0 0 1.7 3h15.8a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
  ok: '<circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/>',
  bad: '<circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/>'
};

function renderBlock(b, opts) {
  switch (b.type) {
    case 'heading': return '<h' + b.level + ' id="' + esc(b.id) + '" class="cs-h">' + b.content + '<a class="cs-anchor" href="#' + esc(b.id) + '" aria-label="Link to section">#</a></h' + b.level + '>';
    case 'paragraph': return '<p>' + b.content + '</p>';
    case 'quote': return '<blockquote class="cs-quote">' + b.content + (b.cite ? ('<cite>' + b.cite + '</cite>') : '') + '</blockquote>';
    case 'list': {
      const tag = b.ordered ? 'ol' : 'ul';
      return '<' + tag + ' class="cs-list">' + b.items.map(function (i) { return '<li>' + i + '</li>'; }).join('') + '</' + tag + '>';
    }
    case 'callout': {
      const ic = ICONS[b.variant] || ICONS.info;
      return '<div class="cs-callout cs-' + b.variant + '"><svg viewBox="0 0 24 24" class="cs-cico">' + ic + '</svg><div>' + (b.title ? ('<b>' + b.title + '</b>') : '') + (b.content ? ('<div>' + b.content + '</div>') : '') + '</div></div>';
    }
    case 'proscons':
      return '<div class="cs-pc"><div class="cs-pros"><h4>Pros</h4><ul>' + b.pros.map(function (x) { return '<li>' + x + '</li>'; }).join('') + '</ul></div><div class="cs-cons"><h4>Cons</h4><ul>' + b.cons.map(function (x) { return '<li>' + x + '</li>'; }).join('') + '</ul></div></div>';
    case 'steps':
      return '<ol class="cs-steps">' + b.items.map(function (s, i) { return '<li><span class="cs-stepn">' + (i + 1) + '</span><div>' + (s.title ? ('<b>' + s.title + '</b>') : '') + (s.content ? ('<div>' + s.content + '</div>') : '') + '</div></li>'; }).join('') + '</ol>';
    case 'faq':
      return '<div class="cs-faq">' + b.items.map(function (f) { return '<details><summary>' + f.q + '</summary><div>' + f.a + '</div></details>'; }).join('') + '</div>';
    case 'table': {
      const head = b.headers.length ? ('<thead><tr>' + b.headers.map(function (h) { return '<th>' + h + '</th>'; }).join('') + '</tr></thead>') : '';
      const body = '<tbody>' + b.rows.map(function (r, ri) { return '<tr' + (b.highlight.indexOf(ri) >= 0 ? ' class="hl"' : '') + '>' + r.map(function (c) { return '<td>' + c + '</td>'; }).join('') + '</tr>'; }).join('') + '</tbody>';
      return '<div class="cs-table-wrap"><table class="cs-table">' + head + body + '</table>' + (b.caption ? ('<div class="cs-cap">' + b.caption + '</div>') : '') + '</div>';
    }
    case 'image':
      return '<figure class="cs-fig' + (b.banner ? ' cs-banner' : '') + '"><img loading="lazy" src="' + esc(b.src) + '" alt="' + b.alt + '" onerror="var f=this.closest(\'figure\'); if(f) f.style.display=\'none\'">' + (b.caption ? ('<figcaption>' + b.caption + '</figcaption>') : '') + '</figure>';
    case 'imagetext':
      return '<div class="cs-imgtext cs-' + b.position + '"><div class="cs-it-img"><img loading="lazy" src="' + esc(b.src) + '" alt="' + b.alt + '"></div><div class="cs-it-txt">' + b.content + '</div></div>';
    case 'youtube':
      return '<div class="cs-embed"><iframe loading="lazy" src="https://www.youtube-nocookie.com/embed/' + esc(b.id) + '" title="Video" allow="accelerometer;autoplay;clipboard-write;encrypted-media;gyroscope;picture-in-picture" allowfullscreen></iframe></div>' + (b.caption ? ('<div class="cs-cap">' + b.caption + '</div>') : '');
    case 'vimeo':
      return '<div class="cs-embed"><iframe loading="lazy" src="https://player.vimeo.com/video/' + esc(b.id) + '" title="Video" allow="autoplay;fullscreen;picture-in-picture" allowfullscreen></iframe></div>';
    case 'button':
      return '<div class="cs-btnrow cs-a-' + (b.button.align || 'left') + '">' + renderButton(b.button, opts) + '</div>';
    case 'cta':
      return '<div class="cs-cta">' + (b.title ? ('<h3>' + b.title + '</h3>') : '') + (b.content ? ('<p>' + b.content + '</p>') : '') + (b.button ? ('<div class="cs-cta-btn">' + renderButton(b.button, opts) + '</div>') : '') + '</div>';
    case 'productcard': {
      const p = opts.products && opts.products[b.ref]; if (!p) return '';
      return '<div class="cs-pgrid cs-one">' + productCard(p) + '</div>';
    }
    case 'productgrid': {
      const cards = (b.refs || []).map(function (r) { return opts.products && opts.products[r]; }).filter(Boolean).map(productCard).join('');
      return cards ? ('<div class="cs-pgrid">' + cards + '</div>') : '';
    }
    case 'categorycard': {
      const c = opts.categories && opts.categories[b.ref]; if (!c) return '';
      return '<a class="cs-catcard" href="/category/' + esc(c.slug) + '"><b>' + esc(c.name) + '</b>' + (c.tag ? ('<span>' + esc(c.tag) + '</span>') : '') + '</a>';
    }
    case 'stats':
      return '<div class="cs-stats">' + b.items.map(function (s) { return '<div class="cs-stat"><b>' + s.value + '</b><span>' + s.label + '</span></div>'; }).join('') + '</div>';
    case 'code':
      return '<pre class="cs-code"><code>' + b.content + '</code></pre>';
    case 'divider': return '<hr class="cs-hr">';
    case 'spacer': return '<div class="cs-spacer cs-' + b.size + '"></div>';
    case 'toc': return '';      // TOC is placed by the page template (sidebar + mobile), not inline
    case 'related': return '';  // Related is placed by the page template, after the article
    default: return '';
  }
}

function renderBlocks(blocks, opts) {
  opts = opts || {};
  return (blocks || []).map(function (b) { return renderBlock(b, opts); }).join('\n');
}

function tocHtml(toc) {
  if (!toc || !toc.length) return '';
  return '<nav class="cs-toc" aria-label="Table of contents"><div class="cs-toc-h">On this page</div><ul>' +
    toc.map(function (t) { return '<li class="cs-toc-l' + t.level + '"><a href="#' + esc(t.id) + '">' + esc(t.text) + '</a></li>'; }).join('') + '</ul></nav>';
}

module.exports = { renderBlocks, tocHtml, productCard, renderButton, btnHref };
