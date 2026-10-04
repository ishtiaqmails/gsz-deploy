#!/usr/bin/env bash
# ============================================================
#  GALAXY SUBZ x ZAYRON  —  STEP 6: clean admin shell (sidebar)
#  RUN: cd /opt/gsz-deploy && git pull && bash step6.sh
#  Rebuilds the admin into a grouped left-sidebar layout with a proper
#  dashboard (stat cards + quick actions). Same routes/data, new shell.
#  Touches ONLY /opt/gsz views. No server/route/schema changes.
# ============================================================
set -euo pipefail
APP=/opt/gsz
[ -d "$APP/views/admin" ] || { echo "ABORT: admin views not found — run step3/step5 first."; exit 1; }
set -a; . "$APP/.env"; set +a
: "${PORT:?}"
echo "== Galaxy Subz x Zayron — Step 6 (clean admin shell) · port $PORT =="
ts=$(date +%s)
mkdir -p "$APP/views/admin/_bak-step6.$ts"
cp -a "$APP"/views/admin/*.ejs "$APP/views/admin/_bak-step6.$ts"/ 2>/dev/null || true

# ---------- shared shell: top ----------
cat > "$APP/views/admin/_shell_top.ejs" <<'GSZ_ST_EOF'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title><%= typeof title!=='undefined'?title:'Admin' %> · Galaxy Subz × Zayron</title>
<style>
  :root{color-scheme:light;--bg:#f4f6fc;--panel:#fff;--ink:#0f1836;--muted:#737e9c;--hair:#e7ebf6;
    --brand:#2a7bff;--violet:#8a2bff;--grad:linear-gradient(118deg,#8a2bff,#2a7bff);--ok:#16b765;--warn:#f5a623;--bad:#e0453f;
    --side:264px}
  *{box-sizing:border-box}
  body{margin:0;font-family:'Hanken Grotesk',system-ui,'Segoe UI',sans-serif;background:var(--bg);color:var(--ink)}
  a{color:inherit;text-decoration:none}
  h1{font-size:26px;letter-spacing:-.02em;margin:0}
  h2{font-size:16px;margin:0 0 4px;letter-spacing:-.01em}
  .sub{color:var(--muted);font-size:14px;margin:4px 0 0}
  .btn{display:inline-flex;align-items:center;gap:7px;font-weight:600;font-size:13.5px;border-radius:9px;padding:9px 14px;cursor:pointer;border:0;transition:.18s;white-space:nowrap}
  .btn-p{background:var(--grad);color:#fff;box-shadow:0 10px 22px -12px rgba(42,123,255,.8)}
  .btn-p:hover{filter:brightness(1.05);transform:translateY(-1px)}
  .btn-g{background:#fff;color:var(--ink);box-shadow:inset 0 0 0 1px var(--hair)}
  .btn-g:hover{box-shadow:inset 0 0 0 1.4px var(--brand);color:var(--brand)}
  .fld{display:block;font-size:13px;font-weight:600;margin-bottom:6px}
  input[type=text],input[type=password],input[type=number],select,textarea{width:100%;padding:10px 12px;border-radius:9px;border:1px solid var(--hair);font-size:14px;margin-bottom:12px;font-family:inherit;background:#fff}
  input:focus,select:focus,textarea:focus{outline:2px solid var(--brand);outline-offset:1px;border-color:transparent}
  .card{background:var(--panel);border-radius:14px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);padding:22px;margin-bottom:18px}
  .card .hint{color:var(--muted);font-size:13px;margin:0 0 16px}
  .flash{background:#e9fbf1;color:#0b7a42;border:1px solid #bdebd0;border-radius:11px;padding:11px 15px;font-size:14px;font-weight:600;margin-bottom:18px}
  table{width:100%;border-collapse:collapse;font-size:14px}
  thead tr{text-align:left;background:#f7f9fe}
  th{padding:12px 16px;font-size:12px;letter-spacing:.03em;text-transform:uppercase;color:var(--muted);font-weight:700}
  td{padding:11px 16px}
  tbody tr{border-top:1px solid var(--hair)}

  /* sidebar */
  .side{position:fixed;top:0;left:0;bottom:0;width:var(--side);background:#fff;border-right:1px solid var(--hair);
    display:flex;flex-direction:column;padding:18px 14px;overflow-y:auto;z-index:40}
  .brand{display:flex;align-items:center;gap:11px;padding:6px 8px 18px}
  .brand .logo{width:38px;height:38px;border-radius:11px;background:var(--grad);display:grid;place-items:center;color:#fff;flex:none;box-shadow:0 10px 20px -10px rgba(138,43,255,.7)}
  .brand b{font-family:'Schibsted Grotesk',sans-serif;font-weight:800;font-size:17px;letter-spacing:-.02em;line-height:1.05}
  .brand .dim{display:block;font-size:11px;color:var(--muted);font-weight:600;letter-spacing:.01em}
  nav .grp{font-size:11px;letter-spacing:.07em;text-transform:uppercase;color:var(--muted);font-weight:700;padding:16px 10px 7px}
  nav a{display:flex;align-items:center;gap:11px;padding:10px 11px;border-radius:10px;font-weight:600;font-size:14px;color:#44506e;margin-bottom:2px;transition:.15s}
  nav a:hover{background:#f3f5fb;color:var(--ink)}
  nav a.on{background:color-mix(in srgb,var(--brand) 12%,#fff);color:var(--brand)}
  nav a svg{width:18px;height:18px;flex:none;stroke:currentColor;fill:none;stroke-width:1.7;stroke-linecap:round;stroke-linejoin:round}

  /* main */
  .main{margin-left:var(--side);min-height:100vh;display:flex;flex-direction:column}
  .tbar{display:flex;align-items:center;gap:12px;padding:0 28px;height:68px;background:rgba(244,246,252,.85);backdrop-filter:blur(10px);position:sticky;top:0;z-index:20;border-bottom:1px solid var(--hair)}
  .tbar .sp{flex:1}
  .content{padding:26px 28px 70px;max-width:1200px;width:100%}

  /* stat cards */
  .stats{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:22px}
  @media(max-width:1000px){.stats{grid-template-columns:repeat(2,1fr)}}
  .stat{background:#fff;border-radius:14px;padding:18px 18px 16px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);position:relative;overflow:hidden}
  .stat:before{content:"";position:absolute;top:0;left:0;right:0;height:3px;background:var(--c,var(--grad))}
  .stat .lbl{font-size:12px;letter-spacing:.04em;text-transform:uppercase;color:var(--muted);font-weight:700;margin-bottom:8px}
  .stat b{font-family:'Schibsted Grotesk',sans-serif;font-size:30px;font-weight:800;letter-spacing:-.02em}
  .qrow{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:22px}

  .mtoggle{display:none;position:fixed;top:14px;left:14px;z-index:60;width:42px;height:42px;border-radius:10px;background:#fff;box-shadow:inset 0 0 0 1px var(--hair);font-size:18px;cursor:pointer}
  .scrim2{display:none;position:fixed;inset:0;background:rgba(15,24,54,.4);z-index:35}
  @media(max-width:880px){
    .side{transform:translateX(-100%);transition:transform .3s}
    body.nav-open .side{transform:none}
    body.nav-open .scrim2{display:block}
    .main{margin-left:0}
    .mtoggle{display:grid;place-items:center}
    .tbar{padding-left:68px}
    .content{padding:20px 16px 60px}
  }
</style>
</head>
<body>
<button class="mtoggle" aria-label="Menu" onclick="document.body.classList.toggle('nav-open')">☰</button>
<div class="scrim2" onclick="document.body.classList.remove('nav-open')"></div>
<aside class="side">
  <div class="brand"><span class="logo"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M12 2l2.4 6.2L21 9l-5 4 1.6 7L12 16.6 6.4 20 8 13 3 9l6.6-.8L12 2z"/></svg></span>
    <b>Galaxy Subz<span class="dim">× Zayron · Admin</span></b></div>
  <nav>
    <% function on(x){ return (typeof active!=='undefined'&&active===x)?'on':'' } %>
    <div class="grp">Overview</div>
    <a href="/admin" class="<%= on('dashboard') %>"><svg viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>Dashboard</a>
    <div class="grp">Catalog</div>
    <a href="/admin/products" class="<%= on('products') %>"><svg viewBox="0 0 24 24"><path d="M3 7l9-4 9 4-9 4-9-4z"/><path d="M3 7v10l9 4 9-4V7"/><path d="M12 11v10"/></svg>Products</a>
    <a href="/admin/categories" class="<%= on('categories') %>"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="4" rx="1"/><rect x="3" y="11" width="18" height="4" rx="1"/><rect x="3" y="18" width="12" height="4" rx="1"/></svg>Categories</a>
    <div class="grp">Branding</div>
    <a href="/admin/branding" class="<%= on('branding') %>"><svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="14" rx="2"/><path d="m3 14 5-4 4 3 4-5 5 6"/></svg>Branding &amp; Banners</a>
  </nav>
</aside>
<main class="main">
  <div class="tbar"><h1><%= typeof title!=='undefined'?title:'Admin' %></h1><div class="sp"></div>
    <a class="btn btn-g" href="/" target="_blank">View site ↗</a>
    <form method="post" action="/admin/logout" style="display:inline"><button class="btn btn-g" type="submit">Log out</button></form>
  </div>
  <div class="content">
GSZ_ST_EOF

# ---------- shared shell: bottom ----------
cat > "$APP/views/admin/_shell_bottom.ejs" <<'GSZ_SB_EOF'
  </div>
</main>
</body></html>
GSZ_SB_EOF

# ---------- dashboard ----------
cat > "$APP/views/admin/dashboard.ejs" <<'GSZ_DB_EOF'
<%- include('_shell_top', { active:'dashboard', title:'Dashboard' }) %>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div class="stats">
  <div class="stat" style="--c:linear-gradient(90deg,#2a7bff,#17cbf0)"><div class="lbl">Categories</div><b><%= counts.c %></b></div>
  <div class="stat" style="--c:linear-gradient(90deg,#8a2bff,#c23bff)"><div class="lbl">Products</div><b><%= counts.p %></b></div>
  <div class="stat" style="--c:linear-gradient(90deg,#16b765,#50d48f)"><div class="lbl">Banner slots</div><b><%= counts.b %></b></div>
  <div class="stat" style="--c:linear-gradient(90deg,#f5a623,#ff6b6b)"><div class="lbl">Site status</div><b style="font-size:22px;color:#0b7a42">Live</b></div>
</div>
<div class="qrow">
  <a class="btn btn-p" href="/admin/products/new">+ Add product</a>
  <a class="btn btn-g" href="/admin/products">Manage products</a>
  <a class="btn btn-g" href="/admin/categories">Categories</a>
  <a class="btn btn-g" href="/admin/branding">Branding &amp; banners</a>
</div>
<div class="card">
  <h2>Catalog</h2>
  <p class="hint">Add or edit products, plans, pricing, descriptions and FAQs, and manage categories.</p>
  <a class="btn btn-p" href="/admin/products">Open Products</a>
</div>
<div class="card">
  <h2>Branding &amp; Banners</h2>
  <p class="hint">Upload your logo and the hero banners. Changes appear on the live site immediately.</p>
  <a class="btn btn-p" href="/admin/branding">Open Branding &amp; Banners</a>
</div>
<%- include('_shell_bottom') %>
GSZ_DB_EOF

# ---------- products list ----------
cat > "$APP/views/admin/products.ejs" <<'GSZ_PL_EOF'
<%- include('_shell_top', { active:'products', title:'Products' }) %>
<div style="display:flex;align-items:center;gap:14px;margin-bottom:6px">
  <div style="flex:1"><p class="sub">Add, edit, show/hide or remove products.</p></div>
  <a class="btn btn-p" href="/admin/products/new">+ Add product</a>
</div>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div class="card" style="padding:0;overflow:hidden">
  <table>
    <thead><tr><th>Product</th><th>Category</th><th>From</th><th>Status</th><th style="text-align:right">Actions</th></tr></thead>
    <tbody>
    <% rows.forEach(function(r){ %>
      <tr>
        <td style="font-weight:600"><%= r.name %></td>
        <td style="color:var(--muted)"><%= r.cat || '—' %></td>
        <td>Rs <%= r.price ? Math.round(r.price).toLocaleString('en-US') : '—' %></td>
        <td><% if (r.hidden || !r.active) { %><span style="color:#b42318;font-weight:600">Hidden</span><% } else { %><span style="color:#0b7a42;font-weight:600">Live</span><% } %></td>
        <td style="text-align:right;white-space:nowrap">
          <a class="btn btn-g" style="padding:6px 11px" href="/admin/products/<%= r.id %>/edit">Edit</a>
          <form method="post" action="/admin/products/<%= r.id %>/toggle" style="display:inline"><button class="btn btn-g" style="padding:6px 11px" type="submit"><%= (r.hidden||!r.active) ? 'Show' : 'Hide' %></button></form>
          <form method="post" action="/admin/products/<%= r.id %>/delete" style="display:inline" onsubmit="return confirm('Delete this product permanently?')"><button class="btn btn-g" style="padding:6px 11px;color:#b42318" type="submit">Delete</button></form>
        </td>
      </tr>
    <% }); %>
    </tbody>
  </table>
</div>
<%- include('_shell_bottom') %>
GSZ_PL_EOF

# ---------- product editor ----------
cat > "$APP/views/admin/product_edit.ejs" <<'GSZ_PE_EOF'
<%- include('_shell_top', { active:'products', title: (prod ? 'Edit product' : 'Add product') }) %>
<div style="max-width:760px">
<p class="sub" style="margin-bottom:18px"><%= prod ? prod.name : 'Create a new product in your catalogue.' %></p>
<form method="post" action="/admin/products/save">
  <% if (prod) { %><input type="hidden" name="id" value="<%= prod.id %>"><% } %>
  <div class="card">
    <label class="fld">Product name</label>
    <input type="text" name="name" value="<%= prod ? prod.name : '' %>" required>
    <label class="fld">Category</label>
    <select name="category_id">
      <% cats.forEach(function(c){ %><option value="<%= c.id %>" <%= (prod && prod.category_id===c.id)?'selected':'' %>><%= c.name %></option><% }); %>
    </select>
    <label class="fld">Short description (shown on cards)</label>
    <input type="text" name="short_desc" value="<%= prod ? (prod.short_desc||'') : '' %>">
    <label class="fld">Delivery label (e.g. "Instant delivery", "Line in minutes")</label>
    <input type="text" name="delivery" value="<%= prod ? (prod.delivery||'') : '' %>">
    <label class="fld">Long description (shown on the product page)</label>
    <textarea name="long_desc" rows="5"><%= prod ? (prod.long_desc||'') : '' %></textarea>
    <label style="display:flex;align-items:center;gap:8px;font-size:14px;font-weight:600"><input type="checkbox" name="hidden" style="width:auto;margin:0" <%= (prod && prod.hidden)?'checked':'' %>> Hide this product from the site</label>
  </div>
  <div class="card">
    <h2>Plans &amp; pricing</h2>
    <p class="hint">Each plan has a label, the price (PKR), and an optional "before" price to show a discount.</p>
    <div id="plans">
      <% (plans.length?plans:[{label:'',price_pkr:'',old_pkr:''}]).forEach(function(pl){ %>
        <div class="prow" style="display:grid;grid-template-columns:1fr 120px 120px 34px;gap:8px;margin-bottom:8px">
          <input type="text" name="plan_label" placeholder="e.g. 1 Month" value="<%= pl.label||'' %>" style="margin:0">
          <input type="number" step="0.01" name="plan_price" placeholder="Price" value="<%= pl.price_pkr||'' %>" style="margin:0">
          <input type="number" step="0.01" name="plan_old" placeholder="Was (opt)" value="<%= pl.old_pkr||'' %>" style="margin:0">
          <button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest('.prow').remove()">✕</button>
        </div>
      <% }); %>
    </div>
    <button type="button" class="btn btn-g" onclick="addPlan()">+ Add plan</button>
  </div>
  <div class="card">
    <h2>FAQs (optional)</h2>
    <p class="hint">Shown as an accordion on the product page.</p>
    <div id="faqs">
      <% (faqs.length?faqs:[]).forEach(function(f){ %>
        <div class="frow" style="display:grid;grid-template-columns:1fr 34px;gap:8px;margin-bottom:8px">
          <div style="display:flex;flex-direction:column;gap:6px">
            <input type="text" name="faq_q" placeholder="Question" value="<%= f.q||'' %>" style="margin:0">
            <input type="text" name="faq_a" placeholder="Answer" value="<%= f.a||'' %>" style="margin:0">
          </div>
          <button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest('.frow').remove()">✕</button>
        </div>
      <% }); %>
    </div>
    <button type="button" class="btn btn-g" onclick="addFaq()">+ Add FAQ</button>
  </div>
  <div style="display:flex;gap:10px"><button class="btn btn-p" type="submit">Save product</button><a class="btn btn-g" href="/admin/products">Cancel</a></div>
</form>
</div>
<script>
function addPlan(){var d=document.createElement('div');d.className='prow';d.style.cssText='display:grid;grid-template-columns:1fr 120px 120px 34px;gap:8px;margin-bottom:8px';
  d.innerHTML='<input type="text" name="plan_label" placeholder="e.g. 1 Month" style="margin:0"><input type="number" step="0.01" name="plan_price" placeholder="Price" style="margin:0"><input type="number" step="0.01" name="plan_old" placeholder="Was (opt)" style="margin:0"><button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest(\'.prow\').remove()">✕</button>';
  document.getElementById('plans').appendChild(d);}
function addFaq(){var d=document.createElement('div');d.className='frow';d.style.cssText='display:grid;grid-template-columns:1fr 34px;gap:8px;margin-bottom:8px';
  d.innerHTML='<div style="display:flex;flex-direction:column;gap:6px"><input type="text" name="faq_q" placeholder="Question" style="margin:0"><input type="text" name="faq_a" placeholder="Answer" style="margin:0"></div><button type="button" class="btn btn-g" style="padding:6px" onclick="this.closest(\'.frow\').remove()">✕</button>';
  document.getElementById('faqs').appendChild(d);}
</script>
<%- include('_shell_bottom') %>
GSZ_PE_EOF

# ---------- categories ----------
cat > "$APP/views/admin/categories.ejs" <<'GSZ_CV_EOF'
<%- include('_shell_top', { active:'categories', title:'Categories' }) %>
<p class="sub" style="margin-bottom:18px">Your storefront groups products by these categories.</p>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div class="card">
  <h2>Add a category</h2>
  <form method="post" action="/admin/categories/save" style="display:grid;grid-template-columns:1fr 1fr auto;gap:10px;align-items:end">
    <div><label class="fld">Name</label><input type="text" name="name" placeholder="e.g. Music" required style="margin:0"></div>
    <div><label class="fld">Tag (small label)</label><input type="text" name="tag" placeholder="e.g. Streaming" style="margin:0"></div>
    <button class="btn btn-p" type="submit">Add</button>
  </form>
</div>
<div class="card" style="padding:0;overflow:hidden">
  <table>
    <thead><tr><th>Category</th><th>Tag</th><th>Products</th><th>Status</th><th style="text-align:right">Actions</th></tr></thead>
    <tbody>
    <% rows.forEach(function(r){ %>
      <tr>
        <td style="font-weight:600"><%= r.name %></td>
        <td style="color:var(--muted)"><%= r.tag || '—' %></td>
        <td><%= r.n %></td>
        <td><% if (r.active) { %><span style="color:#0b7a42;font-weight:600">Live</span><% } else { %><span style="color:#b42318;font-weight:600">Hidden</span><% } %></td>
        <td style="text-align:right;white-space:nowrap">
          <form method="post" action="/admin/categories/<%= r.id %>/toggle" style="display:inline"><button class="btn btn-g" style="padding:6px 11px" type="submit"><%= r.active ? 'Hide' : 'Show' %></button></form>
        </td>
      </tr>
    <% }); %>
    </tbody>
  </table>
</div>
<%- include('_shell_bottom') %>
GSZ_CV_EOF

# ---------- branding ----------
cat > "$APP/views/admin/branding.ejs" <<'GSZ_BR_EOF'
<%- include('_shell_top', { active:'branding', title:'Branding & Banners' }) %>
<p class="sub" style="margin-bottom:18px">Upload your real logo and hero banners. Each slot shows the exact size to use.</p>
<% if (flash) { %><div class="flash"><%= flash %></div><% } %>
<div class="card">
  <h2>Logo</h2>
  <p class="hint">Transparent PNG or SVG works best. Shown in the header and footer.</p>
  <% var lf = settings.logo_file || 'logo.png'; %>
  <img style="height:52px;margin-bottom:12px" src="/static/img/<%= lf %>?v=<%= Date.now() %>" alt="Current logo" onerror="this.style.display='none'">
  <form method="post" action="/admin/branding/logo" enctype="multipart/form-data">
    <input type="file" name="logo" accept="image/*" required style="font-size:13px;margin-bottom:10px">
    <div><button class="btn btn-p" type="submit">Upload logo</button></div>
  </form>
</div>
<div class="card">
  <h2>Hero banners</h2>
  <p class="hint">Each category has a <b>desktop</b> and a <b>mobile</b> banner. The site shows the right one per device automatically.</p>
  <% slots.forEach(function(s){ var cur = map[s.slug] || {}; %>
    <div style="border:1px solid var(--hair);border-radius:12px;padding:14px;margin-bottom:14px">
      <h3 style="font-size:14px;margin:0 0 10px"><%= s.name %></h3>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px">
        <% ['desktop','mobile'].forEach(function(dev){ %>
          <div style="border:1px dashed var(--hair);border-radius:10px;padding:12px;background:#fafbff">
            <div style="font-weight:700;font-size:13px"><%= dev.charAt(0).toUpperCase()+dev.slice(1) %></div>
            <div style="color:var(--muted);font-size:12px;margin:2px 0 10px">Required size: <%= dims[dev] %></div>
            <% if (cur[dev]) { %>
              <img style="width:100%;aspect-ratio:16/9;object-fit:cover;border-radius:8px;margin-bottom:10px;display:block" src="/static/img/<%= cur[dev] %>?v=<%= Date.now() %>" alt="">
            <% } else { %>
              <div style="width:100%;aspect-ratio:16/9;border-radius:8px;background:repeating-linear-gradient(45deg,#eef2fe,#eef2fe 10px,#e3e8f6 10px,#e3e8f6 20px);display:grid;place-items:center;color:var(--muted);font-size:12px;margin-bottom:10px">No banner yet</div>
            <% } %>
            <form method="post" action="/admin/branding/banner" enctype="multipart/form-data">
              <input type="hidden" name="category_slug" value="<%= s.slug %>">
              <input type="hidden" name="device" value="<%= dev %>">
              <input type="file" name="banner" accept="image/*" required style="font-size:13px;width:100%;margin-bottom:10px">
              <button class="btn btn-p" type="submit" style="width:100%;justify-content:center"><%= cur[dev] ? 'Replace' : 'Upload' %></button>
            </form>
          </div>
        <% }); %>
      </div>
    </div>
  <% }); %>
</div>
<%- include('_shell_bottom') %>
GSZ_BR_EOF

# ---------- login (standalone, matching style) ----------
cat > "$APP/views/admin/login.ejs" <<'GSZ_LG_EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Admin sign in · Galaxy Subz × Zayron</title>
<style>
  :root{color-scheme:light;--ink:#0f1836;--muted:#737e9c;--hair:#e7ebf6;--grad:linear-gradient(118deg,#8a2bff,#2a7bff)}
  *{box-sizing:border-box}body{margin:0;font-family:'Hanken Grotesk',system-ui,sans-serif;background:#f4f6fc;color:var(--ink);display:grid;place-items:center;min-height:100vh}
  .box{width:100%;max-width:370px;padding:20px}
  .brand{display:flex;align-items:center;gap:11px;margin-bottom:20px}
  .brand .logo{width:40px;height:40px;border-radius:12px;background:var(--grad);display:grid;place-items:center;color:#fff}
  .brand b{font-family:'Schibsted Grotesk',sans-serif;font-weight:800;font-size:18px;letter-spacing:-.02em}
  h1{font-size:22px;margin:0 0 4px}.sub{color:var(--muted);font-size:14px;margin:0 0 20px}
  .card{background:#fff;border-radius:14px;box-shadow:0 1px 2px rgba(15,24,54,.04),0 16px 34px -26px rgba(15,24,54,.28);padding:22px}
  label{display:block;font-size:13px;font-weight:600;margin-bottom:6px}
  input{width:100%;padding:11px 12px;border-radius:9px;border:1px solid var(--hair);font-size:14px;margin-bottom:14px;font-family:inherit}
  input:focus{outline:2px solid #2a7bff;outline-offset:1px;border-color:transparent}
  button{width:100%;background:var(--grad);color:#fff;font-weight:700;font-size:15px;border:0;border-radius:10px;padding:12px;cursor:pointer}
  .err{background:#fdecec;color:#b42318;border:1px solid #f6c9c4;border-radius:10px;padding:10px 13px;font-size:14px;font-weight:600;margin-bottom:16px}
</style></head><body>
<div class="box">
  <div class="brand"><span class="logo"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M12 2l2.4 6.2L21 9l-5 4 1.6 7L12 16.6 6.4 20 8 13 3 9l6.6-.8L12 2z"/></svg></span><b>Galaxy Subz × Zayron</b></div>
  <h1>Admin sign in</h1><p class="sub">Control panel</p>
  <% if (error) { %><div class="err"><%= error %></div><% } %>
  <form method="post" action="/admin/login" class="card">
    <label>Username</label><input type="text" name="username" autocomplete="username" autofocus>
    <label>Password</label><input type="password" name="password" autocomplete="current-password">
    <button type="submit">Sign in</button>
  </form>
</div></body></html>
GSZ_LG_EOF

# ---------- remove now-unused old partial (kept as backup copy above) ----------
rm -f "$APP/views/admin/_layout_top.ejs"

echo "[ok] admin shell + all views rewritten"

pm2 restart gsz --update-env >/dev/null
sleep 1.6
LOGIN=$(curl -fsS "http://127.0.0.1:$PORT/admin/login" || true)
CODE=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/admin/products")
if echo "$LOGIN" | grep -q "Admin sign in" && { [ "$CODE" = "302" ] || [ "$CODE" = "200" ]; }; then
  echo "[ok] admin login renders + routes gated (/admin/products -> HTTP $CODE)"
else
  echo "CHECK FAILED (HTTP $CODE) — rolling back admin views"
  cp -a "$APP/views/admin/_bak-step6.$ts"/*.ejs "$APP/views/admin"/ 2>/dev/null || true
  pm2 restart gsz >/dev/null; pm2 logs gsz --lines 25 --nostream || true; exit 1
fi
echo "============================================================"
echo " STEP 6 COMPLETE — clean sidebar admin is live"
echo "   open:  http://143.198.209.68:$PORT/admin"
echo "   Grouped sidebar (Overview · Catalog · Branding), stat-card dashboard."
echo "   More sidebar groups (Sales, Payments, Vendors...) get added as we build them."
echo "============================================================"
