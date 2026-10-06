/* ============================================================
   Galaxy Subz × Zayron — shopping cart (self-contained)
   localStorage-backed, with account sync: when signed in, the cart
   merges into the customer's saved cart and follows them across devices.
   Floating button + slide-in drawer. Renders /cart when #cartPage present.
   ============================================================ */
(function () {
  var KEY = 'gsz_cart';
  var AUTH = (typeof window !== 'undefined' && window.__GSZAUTH === true);
  var syncT;

  function read() {
    try { var a = JSON.parse(localStorage.getItem(KEY) || '[]'); return Array.isArray(a) ? a : []; }
    catch (e) { return []; }
  }
  function store(items) { try { localStorage.setItem(KEY, JSON.stringify(items)); } catch (e) {} }
  function write(items) {
    store(items);
    paint();
    document.dispatchEvent(new CustomEvent('gsz:cart', { detail: { items: items } }));
    syncPush();
  }
  /* ---- account sync ---- */
  function serverMerge(incoming, cb) {
    try {
      fetch('/api/cart/sync', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ items: incoming }) })
        .then(function (r) { return r.json(); })
        .then(function (d) { if (d && d.items && cb) cb(d.items); })
        .catch(function () {});
    } catch (e) {}
  }
  function syncPush() { if (!AUTH) return; clearTimeout(syncT); syncT = setTimeout(function () { serverMerge(read()); }, 800); }
  function pullMerge() {
    if (!AUTH) return;
    serverMerge(read(), function (items) { store(items); paint(); });
  }

  function money(pkr) { return 'Rs ' + Math.round(Number(pkr) || 0).toLocaleString('en-US'); }
  function esc(s) { return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function lineId(it) { return it.slug + '|' + it.planIdx + '|' + (it.type || ''); }

  var Cart = {
    get: read,
    count: function () { return read().reduce(function (n, it) { return n + (Number(it.qty) || 1); }, 0); },
    totalPkr: function () { return read().reduce(function (s, it) { return s + (Number(it.pricePkr) || 0) * (Number(it.qty) || 1); }, 0); },
    add: function (it) {
      it.qty = Number(it.qty) || 1;
      var items = read();
      var id = lineId(it);
      var ex = items.filter(function (x) { return lineId(x) === id; })[0];
      if (ex) ex.qty = (Number(ex.qty) || 1) + it.qty;
      else items.push(it);
      write(items);
    },
    setQty: function (id, q) {
      q = Math.max(1, parseInt(q, 10) || 1);
      var items = read().map(function (x) { if (lineId(x) === id) x.qty = q; return x; });
      write(items);
    },
    remove: function (id) { write(read().filter(function (x) { return lineId(x) !== id; })); },
    clear: function () { write([]); }
  };
  window.GSZCart = Cart;

  /* ---------- floating button + drawer (injected once) ---------- */
  function buildUI() {
    if (document.getElementById('gszCartBtn')) return;

    var btn = document.createElement('button');
    btn.id = 'gszCartBtn'; btn.className = 'gszcart-fab'; btn.type = 'button'; btn.setAttribute('aria-label', 'Open cart');
    btn.innerHTML =
      '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2 3h2.2l2.2 12.4a2 2 0 0 0 2 1.6h8.4a2 2 0 0 0 2-1.6L21 7H6"/></svg>' +
      '<span class="gszcart-badge" id="gszCartBadge">0</span>';
    btn.addEventListener('click', open);
    document.body.appendChild(btn);

    var scrim = document.createElement('div');
    scrim.id = 'gszCartScrim'; scrim.className = 'gszcart-scrim';
    scrim.addEventListener('click', close);
    document.body.appendChild(scrim);

    var d = document.createElement('aside');
    d.id = 'gszCartDrawer'; d.className = 'gszcart-drawer'; d.setAttribute('aria-label', 'Your cart');
    d.innerHTML =
      '<div class="gszcart-top"><b>Your cart</b><button class="gszcart-x" id="gszCartX" type="button" aria-label="Close">' +
      '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button></div>' +
      '<div class="gszcart-body" id="gszCartBody"></div>' +
      '<div class="gszcart-foot" id="gszCartFoot"></div>';
    document.body.appendChild(d);
    document.getElementById('gszCartX').addEventListener('click', close);

    paint();
  }

  function itemRow(it) {
    var id = lineId(it);
    var media = it.img
      ? '<img src="/static/img/' + esc(it.img) + '" alt="">'
      : '<span class="ph">' + esc((it.name || '?').charAt(0).toUpperCase()) + '</span>';
    return '<div class="gszcart-item" data-id="' + esc(id) + '">' +
      '<div class="gszcart-thumb">' + media + '</div>' +
      '<div class="gszcart-meta">' +
        '<div class="gszcart-nm">' + esc(it.name) + '</div>' +
        '<div class="gszcart-sub">' + esc(it.planLabel || '') + (it.typeLabel ? (' · ' + esc(it.typeLabel)) : '') + '</div>' +
        '<div class="gszcart-qrow">' +
          '<div class="gszcart-qty"><button type="button" data-act="dec" aria-label="Less">−</button><span>' + (Number(it.qty) || 1) + '</span><button type="button" data-act="inc" aria-label="More">+</button></div>' +
          '<span class="gszcart-price">' + money((Number(it.pricePkr) || 0) * (Number(it.qty) || 1)) + '</span>' +
        '</div>' +
      '</div>' +
      '<button class="gszcart-rm" type="button" data-act="rm" aria-label="Remove">' +
        '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/></svg></button>' +
      '</div>';
  }

  function bindRows(container) {
    container.querySelectorAll('.gszcart-item').forEach(function (row) {
      var id = row.getAttribute('data-id');
      row.querySelectorAll('[data-act]').forEach(function (b) {
        b.addEventListener('click', function () {
          var act = b.getAttribute('data-act');
          var it = read().filter(function (x) { return lineId(x) === id; })[0];
          if (!it) return;
          if (act === 'inc') Cart.setQty(id, (Number(it.qty) || 1) + 1);
          else if (act === 'dec') Cart.setQty(id, (Number(it.qty) || 1) - 1);
          else if (act === 'rm') Cart.remove(id);
        });
      });
    });
  }

  function paintDrawer() {
    var body = document.getElementById('gszCartBody'), foot = document.getElementById('gszCartFoot');
    if (!body || !foot) return;
    var items = read();
    if (!items.length) {
      body.innerHTML = '<div class="gszcart-empty">' +
        '<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="20" r="1.4"/><circle cx="18" cy="20" r="1.4"/><path d="M2 3h2.2l2.2 12.4a2 2 0 0 0 2 1.6h8.4a2 2 0 0 0 2-1.6L21 7H6"/></svg>' +
        '<p>Your cart is empty.</p><a class="gszcart-browse" href="/">Browse the store</a></div>';
      foot.innerHTML = '';
      return;
    }
    body.innerHTML = items.map(itemRow).join('');
    bindRows(body);
    foot.innerHTML =
      '<div class="gszcart-sum"><span>Subtotal</span><b>' + money(Cart.totalPkr()) + '</b></div>' +
      '<a class="gszcart-go" href="/cart">Proceed to checkout</a>' +
      '<p class="gszcart-note">Add several products and pay once — we deliver each item to your email &amp; WhatsApp.</p>';
  }

  /* ---------- /cart review page ---------- */
  function paintPage() {
    var page = document.getElementById('cartPage');
    if (!page) return;
    var items = read();
    if (!items.length) {
      page.innerHTML = '<div class="cartpage-empty"><h2>Your cart is empty</h2><p>Browse the store and add a few products — then check out once.</p><a class="btn btn-primary" href="/">Browse the store</a></div>';
      return;
    }
    page.innerHTML =
      '<div class="cartpage-grid">' +
        '<div class="cartpage-list" id="cartPageList">' + items.map(itemRow).join('') + '</div>' +
        '<aside class="cartpage-side">' +
          '<div class="cartpage-sum">' +
            '<h2>Order summary</h2>' +
            '<div class="cps-row"><span>Items</span><b>' + Cart.count() + '</b></div>' +
            '<div class="cps-row cps-tot"><span>Subtotal</span><b id="cartPageTotal">' + money(Cart.totalPkr()) + '</b></div>' +
            '<form method="post" action="/cart/checkout" id="cartGoForm"><input type="hidden" name="cart" id="cartGoData"><button class="btn btn-primary cps-go" type="submit">Continue to checkout</button></form>' +
            '<p class="cps-note">You pay once for everything. Each item is delivered to your email &amp; WhatsApp after we verify your payment.</p>' +
          '</div>' +
        '</aside>' +
      '</div>';
    bindRows(document.getElementById('cartPageList'));
    var form = document.getElementById('cartGoForm');
    if (form) form.addEventListener('submit', function () { document.getElementById('cartGoData').value = JSON.stringify(read()); });
  }

  /* ---------- open / close / paint ---------- */
  function open() { var d = document.getElementById('gszCartDrawer'), s = document.getElementById('gszCartScrim'); if (d) d.classList.add('on'); if (s) s.classList.add('on'); document.body.style.overflow = 'hidden'; }
  function close() { var d = document.getElementById('gszCartDrawer'), s = document.getElementById('gszCartScrim'); if (d) d.classList.remove('on'); if (s) s.classList.remove('on'); document.body.style.overflow = ''; }
  Cart.open = open; Cart.close = close;

  function paint() {
    var n = Cart.count();
    var badge = document.getElementById('gszCartBadge');
    if (badge) { badge.textContent = n; badge.style.display = n > 0 ? '' : 'none'; }
    var fab = document.getElementById('gszCartBtn');
    if (fab) fab.classList.toggle('has', n > 0);
    paintDrawer();
    paintPage();
  }

  function init() { buildUI(); paint(); pullMerge(); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
  document.addEventListener('gsz:cart', paint);
})();
