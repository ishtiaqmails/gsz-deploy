'use strict';
/* WhatsApp template composer. Each template holds a per-language body (langs
   jsonb: {en,ur,ar,ro,...}); the enabled languages come from wa_settings.wa_langs.
   compose() renders every enabled language with the given vars and stacks them
   into one message. Falls back to the plain `body` (English) when needed. */
function render(body, vars) { return String(body || '').replace(/\{\{(\w+)\}\}/g, (_, k) => (vars && vars[k] != null) ? String(vars[k]) : ''); }

async function enabledLangs(pool) {
  try {
    const r = (await pool.query("SELECT value FROM wa_settings WHERE key='wa_langs'")).rows[0];
    const v = (r && r.value) ? r.value : 'en';
    const list = v.split(',').map(x => x.trim()).filter(Boolean);
    return list.length ? list : ['en'];
  } catch (e) { return ['en']; }
}

async function compose(pool, key, vars) {
  let t;
  try { t = (await pool.query('SELECT body, langs FROM wa_templates WHERE key=$1', [key])).rows[0]; } catch (e) { t = null; }
  if (!t) return '(' + key + ')';
  const langs = t.langs && typeof t.langs === 'object' ? t.langs : {};
  const codes = await enabledLangs(pool);
  const parts = [];
  codes.forEach(code => {
    let body = (langs && langs[code]) ? langs[code] : (code === 'en' ? t.body : '');
    if (body && String(body).trim()) parts.push(render(body, vars));
  });
  if (!parts.length) parts.push(render(t.body || '', vars));
  return parts.join('\n———\n');
}

module.exports = { compose, render };
