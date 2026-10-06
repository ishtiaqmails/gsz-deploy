'use strict';
/* Customer accounts — Phase 1: sign-up, login, logout, email verification.
   Passwords hashed with Node's built-in crypto.scrypt (no extra dependency).
   Mounted at '/' in server.js. WhatsApp verification = Phase 2 (stub here).
   The storefront session is express-session; we keep a slim customer on it. */
const express = require('express');
const crypto = require('crypto');
const storefront = require('../lib/storefront');
const phone = require('../lib/phone');
let mailer = null; try { mailer = require('../lib/mailer'); } catch (e) { mailer = { configured: () => false, send: async () => ({ skipped: true }) }; }

module.exports = function (pool) {
  const router = express.Router();
  const body = express.urlencoded({ extended: true, limit: '64kb' });

  // ---- password hashing (scrypt) ----
  function hashPw(pw) {
    const salt = crypto.randomBytes(16);
    const dk = crypto.scryptSync(String(pw), salt, 64);
    return 's1$' + salt.toString('hex') + '$' + dk.toString('hex');
  }
  function verifyPw(pw, stored) {
    try {
      const parts = String(stored || '').split('$');
      if (parts.length !== 3 || parts[0] !== 's1') return false;
      const salt = Buffer.from(parts[1], 'hex');
      const want = Buffer.from(parts[2], 'hex');
      const dk = crypto.scryptSync(String(pw), salt, 64);
      return dk.length === want.length && crypto.timingSafeEqual(dk, want);
    } catch (e) { return false; }
  }

  // ---- helpers ----
  const normEmail = s => String(s || '').trim().toLowerCase();
  const digits = s => String(s || '').replace(/[^0-9]/g, '');
  const emailOk = s => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s);
  const gen6 = () => String(Math.floor(100000 + Math.random() * 900000));
  const slim = c => ({ id: c.id, name: c.name, email: c.email, email_verified: !!c.email_verified, wa_number: c.wa_number || '', wa_verified: !!c.wa_verified });

  async function shell() {
    const cats = await storefront.loadCats(pool);
    const settings = await storefront.loadSettings(pool);
    const products = await storefront.loadProducts(pool);
    const waNumber = settings.wa_number || process.env.WA_NUMBER || '';
    const siteName = settings.site_name || 'Galaxy Subz × Zayron';
    const logoFile = settings.logo_file || 'logo.png';
    const shellJson = storefront.shellJson(cats, products, settings, waNumber);
    return { cats, settings, waNumber, siteName, logoFile, shellJson };
  }
  function requireLogin(req, res, next) {
    if (req.session && req.session.customer) return next();
    const back = encodeURIComponent(req.originalUrl || '/account');
    return res.redirect('/login?next=' + back);
  }
  function safeNext(n) {
    n = String(n || '');
    return (n.charAt(0) === '/' && n.charAt(1) !== '/') ? n : '/account';
  }

  async function sendEmailCode(c) {
    const code = gen6();
    await pool.query(
      `INSERT INTO customer_tokens(customer_id, kind, code, expires_at) VALUES($1,'email_verify',$2, now() + interval '30 minutes')`,
      [c.id, code]);
    const site = (await storefront.loadSettings(pool)).site_name || 'Galaxy Subz × Zayron';
    const html = `<div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:28px 26px;background:#ffffff;border:1px solid #eceef3;border-radius:16px">
      <h1 style="font-size:19px;margin:0 0 4px;color:#0f1424">${site}</h1>
      <p style="color:#5a6276;font-size:14px;margin:0 0 20px">Confirm your email address</p>
      <p style="color:#2a3146;font-size:15px;margin:0 0 14px">Enter this code to verify your account:</p>
      <div style="font-size:34px;font-weight:800;letter-spacing:8px;color:#1b2440;background:#f4f6fb;border-radius:12px;text-align:center;padding:16px 0;margin:0 0 18px">${code}</div>
      <p style="color:#8a90a2;font-size:12.5px;margin:0">This code expires in 30 minutes. If you didn't create an account, you can ignore this email.</p>
    </div>`;
    try { if (mailer && mailer.configured && mailer.configured()) await mailer.send(c.email, 'Your ' + site + ' verification code', html); } catch (e) { /* email must never break signup */ }
    return mailer && mailer.configured && mailer.configured();
  }

  // ---- LOGIN ----
  router.get('/login', async (req, res) => {
    if (req.session && req.session.customer) return res.redirect('/account');
    res.render('account/login', Object.assign(await shell(), { title: 'Sign in', error: null, email: '', next: req.query.next || '' }));
  });
  router.post('/login', body, async (req, res) => {
    const idf = String(req.body.email || '').trim(), next = req.body.next;
    const re = (err) => shell().then(s => res.render('account/login', Object.assign(s, { title: 'Sign in', error: err, email: idf, next })));
    if (!idf || !req.body.password) return re('Enter your email or phone, and your password.');
    try {
      let c = null;
      if (idf.indexOf('@') >= 0) {
        c = (await pool.query('SELECT * FROM customers WHERE email=$1', [normEmail(idf)])).rows[0];
      } else {
        const n = phone.normalize(idf, req.body.wa_country || undefined);
        const dig = n.digits || digits(idf);
        if (dig.length >= 6) {
          c = (await pool.query("SELECT * FROM customers WHERE wa_number=$1 OR wa_number LIKE '%'||$2 ORDER BY id LIMIT 1", [dig, dig.slice(-9)])).rows[0];
        }
      }
      if (!c || !verifyPw(req.body.password, c.pass_hash)) return re('Those details are incorrect. Check your email/phone and password.');
      await pool.query('UPDATE customers SET last_login=now() WHERE id=$1', [c.id]);
      req.session.customer = slim(c);
      res.redirect(safeNext(next));
    } catch (e) { re('Something went wrong. Please try again.'); }
  });

  // ---- SIGN UP ----
  router.get('/signup', async (req, res) => {
    if (req.session && req.session.customer) return res.redirect('/account');
    res.render('account/signup', Object.assign(await shell(), { title: 'Create account', error: null, form: {}, countries: phone.countries() }));
  });
  router.post('/signup', body, async (req, res) => {
    const b = req.body;
    const waNorm = phone.normalize(b.wa, b.wa_country);
    const form = { name: String(b.name || '').trim(), email: normEmail(b.email), wa: waNorm.digits, wa_country: String(b.wa_country||'') };
    const re = (err) => shell().then(s => res.render('account/signup', Object.assign(s, { title: 'Create account', error: err, form, countries: phone.countries() })));
    if (form.name.length < 2) return re('Please enter your name.');
    if (!emailOk(form.email)) return re('Please enter a valid email address.');
    if (!waNorm.ok) return re('Please enter a valid WhatsApp number for the country you selected.');
    if (String(b.password || '').length < 8) return re('Password must be at least 8 characters.');
    if (b.password !== b.password2) return re('The two passwords do not match.');
    try {
      const exists = (await pool.query('SELECT id FROM customers WHERE email=$1', [form.email])).rows[0];
      if (exists) return re('That email is already registered — try signing in instead.');
      const r = await pool.query(
        `INSERT INTO customers(name,email,wa_number,pass_hash) VALUES($1,$2,$3,$4) RETURNING *`,
        [form.name, form.email, form.wa, hashPw(b.password)]);
      const c = r.rows[0];
      req.session.customer = slim(c);
      await sendEmailCode(c);
      res.redirect('/account/verify-email');
    } catch (e) {
      if (String(e.message || '').indexOf('duplicate') >= 0) return re('That email is already registered — try signing in instead.');
      re('Could not create your account. Please try again.');
    }
  });

  // ---- LOGOUT ----
  router.post('/logout', (req, res) => {
    if (req.session) delete req.session.customer;
    res.redirect('/');
  });

  // ---- EMAIL VERIFICATION ----
  router.get('/account/verify-email', requireLogin, async (req, res) => {
    const c = req.session.customer;
    if (c.email_verified) return res.redirect('/account');
    res.render('account/verify_email', Object.assign(await shell(), {
      title: 'Verify your email', error: null,
      sent: req.query.sent === '1', mailOn: !!(mailer && mailer.configured && mailer.configured()), email: c.email
    }));
  });
  router.post('/account/verify-email', body, requireLogin, async (req, res) => {
    const c = req.session.customer;
    const code = String(req.body.code || '').replace(/[^0-9]/g, '');
    const re = (err) => shell().then(s => res.render('account/verify_email', Object.assign(s, {
      title: 'Verify your email', error: err, sent: false,
      mailOn: !!(mailer && mailer.configured && mailer.configured()), email: c.email
    })));
    if (code.length !== 6) return re('Enter the 6-digit code from your email.');
    try {
      const t = (await pool.query(
        `SELECT * FROM customer_tokens WHERE customer_id=$1 AND kind='email_verify' AND used=false AND expires_at > now() ORDER BY id DESC LIMIT 1`,
        [c.id])).rows[0];
      if (!t) return re('That code has expired. Tap “Resend code” for a new one.');
      if (t.tries >= 6) return re('Too many attempts. Tap “Resend code” for a fresh code.');
      if (String(t.code) !== code) {
        await pool.query('UPDATE customer_tokens SET tries = tries + 1 WHERE id=$1', [t.id]);
        return re('That code is not correct. Please check and try again.');
      }
      await pool.query('UPDATE customer_tokens SET used=true WHERE id=$1', [t.id]);
      await pool.query('UPDATE customers SET email_verified=true WHERE id=$1', [c.id]);
      req.session.customer.email_verified = true;
      res.redirect('/account?ok=email');
    } catch (e) { re('Something went wrong. Please try again.'); }
  });
  router.post('/account/verify-email/resend', requireLogin, async (req, res) => {
    const c = req.session.customer;
    try { const full = (await pool.query('SELECT * FROM customers WHERE id=$1', [c.id])).rows[0]; if (full && !full.email_verified) await sendEmailCode(full); } catch (e) {}
    res.redirect('/account/verify-email?sent=1');
  });

  // ---- DASHBOARD (Phase 1: profile + verification; orders/trials come in Phase 3) ----
  router.get('/account', requireLogin, async (req, res) => {
    let c = req.session.customer;
    try {
      const full = (await pool.query('SELECT * FROM customers WHERE id=$1', [c.id])).rows[0];
      if (full) { req.session.customer = slim(full); c = req.session.customer; } else { delete req.session.customer; return res.redirect('/login'); }
    } catch (e) {}
    let wa={verified:false,phone:''}; /*waStatusLink*/
    try{ const L=(await pool.query("SELECT i.current_phone_e164 FROM customer_whatsapp_links l JOIN whatsapp_identities i ON i.id=l.whatsapp_identity_id WHERE l.customer_id=$1 AND l.status='ACTIVE' AND l.is_primary=true LIMIT 1",[c.id])).rows[0]; if(L){ wa.verified=true; wa.phone=L.current_phone_e164||''; } }catch(e){}
    let orders=[]; /*ordersLink*/
    try{ orders=(await pool.query("SELECT id, order_no, status, product_name, plan_label, amount_display, currency, created_at FROM orders WHERE customer_id=$1 OR (customer_id IS NULL AND email IS NOT NULL AND lower(email)=lower($2)) ORDER BY id DESC LIMIT 8",[c.id, c.email])).rows; }catch(e){}
    res.render('account/dashboard', Object.assign(await shell(), { title: 'My account', c, ok: req.query.ok || null, wa, orders }));
  });

  return router;
};
