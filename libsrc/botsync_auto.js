'use strict';
/* Automatic bot catalogue sync. Pulls the bot's live products into bot_products
   once shortly after boot, then on a fixed interval — so products added on the
   reseller bot appear on the website without anyone clicking "Sync".
   The manual /admin/bot/sync button still works for instant syncs. */
const { syncProducts } = require('./botsync');

module.exports = function startAutoSync(pool, everyMs) {
  const period = Number(everyMs) > 0 ? Number(everyMs) : 600000; // default 10 min
  let running = false;
  async function run(why) {
    if (running) return;            // never overlap
    running = true;
    try {
      const n = await syncProducts(pool);
      console.log('[botsync] ' + why + ': synced ' + n + ' products');
    } catch (e) {
      console.error('[botsync] ' + why + ' failed:', e && e.message);
    } finally { running = false; }
  }
  setTimeout(function () { run('startup'); }, 8000);   // once, ~8s after boot
  const t = setInterval(function () { run('interval'); }, period);
  if (t && t.unref) t.unref();                          // don't keep process alive just for this
  return { runNow: function () { return run('manual'); } };
};
