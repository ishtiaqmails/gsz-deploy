'use strict';
/* lib/loginlimit.js — fail-safe, in-memory brute-force throttle for the password login.
 * Per client IP: after MAX failed logins within WINDOW, block further attempts for BLOCK.
 * A successful login clears the counter. Everything is wrapped so the limiter can NEVER block a
 * legitimate login on its own error — it fails OPEN. Single PM2 process, so in-memory is fine. */
const WINDOW = 15 * 60 * 1000;   // rolling window for counting failures
const MAX = 10;                  // failures allowed in the window before a block
const BLOCK = 15 * 60 * 1000;    // how long a blocked IP stays blocked

const m = new Map(); // ip -> { first, count, until }

function slot(k) {
  const now = Date.now();
  let h = m.get(k);
  if (!h || (now - h.first > WINDOW && (!h.until || now > h.until))) { h = { first: now, count: 0, until: 0 }; m.set(k, h); }
  return h;
}
function blocked(k) { try { const h = m.get(k); return !!(h && h.until && Date.now() < h.until); } catch (e) { return false; } }
function fail(k)   { try { const h = slot(k); h.count++; if (h.count >= MAX) h.until = Date.now() + BLOCK; } catch (e) {} }
function ok(k)     { try { m.delete(k); } catch (e) {} }

// periodic cleanup so the map can't grow unbounded
try {
  const t = setInterval(function () {
    try { const now = Date.now(); for (const [k, h] of m) { if ((!h.until || now > h.until) && now - h.first > WINDOW) m.delete(k); } } catch (e) {}
  }, 10 * 60 * 1000);
  if (t && t.unref) t.unref();
} catch (e) {}

module.exports = { blocked, fail, ok };
