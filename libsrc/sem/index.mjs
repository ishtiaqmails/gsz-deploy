// GSZ semantic brain — self-hosted sidecar (local MiniLM embeddings, no external API).
// The main store app pushes the knowledge corpus here (/reindex) and asks for the closest
// matches per customer message (/match). Runs on 127.0.0.1 only. If this process is down,
// the main bot falls back to its keyword engine — the live site is never affected.
import express from 'express';
import { pipeline, cos_sim, env } from '@xenova/transformers';
env.cacheDir = './models';
env.allowLocalModels = false;

const PORT = Number(process.env.SEM_PORT || 3910);
let extractor = null, ready = false;
let IDX = { products: [], faqs: [], categories: [], intents: [], builtAt: 0 };

async function load() {
  const t0 = Date.now();
  extractor = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
  ready = true;
  console.log('[sem] model ready in ' + ((Date.now() - t0) / 1000).toFixed(1) + 's');
}
async function embed(text) {
  const o = await extractor(String(text == null ? '' : text).slice(0, 512), { pooling: 'mean', normalize: true });
  return Array.from(o.data);
}
function top(vec, arr) { let best = null; for (const it of arr) { const s = cos_sim(vec, it.vec); if (!best || s > best.s) best = { it, s }; } return best; }
function topN(vec, arr, n) { return arr.map(it => ({ it, s: cos_sim(vec, it.vec) })).sort((a, b) => b.s - a.s).slice(0, n); }

const app = express();
app.use(express.json({ limit: '4mb' }));

app.get('/health', (req, res) => res.json({ ok: true, ready, builtAt: IDX.builtAt,
  counts: { products: IDX.products.length, faqs: IDX.faqs.length, categories: IDX.categories.length, intents: IDX.intents.length } }));

// Replace the whole index from the corpus the main app sends.
app.post('/reindex', async (req, res) => {
  try {
    if (!ready) return res.json({ ok: false, error: 'not_ready' });
    const b = req.body || {};
    const next = { products: [], faqs: [], categories: [], intents: [], builtAt: Date.now() };
    for (const p of (b.products || [])) next.products.push({ id: p.id, name: p.name, cat_slug: p.cat_slug, vec: await embed(p.text || p.name) });
    for (const f of (b.faqs || [])) next.faqs.push({ id: f.id, productId: f.productId || null, q: f.q, a: f.a, vec: await embed((f.q || '') + '. ' + (f.a || '')) });
    for (const c of (b.categories || [])) next.categories.push({ slug: c.slug, name: c.name, vec: await embed(c.name) });
    for (const it of (b.intents || [])) next.intents.push({ intent: it.intent, phrase: it.phrase, vec: await embed(it.phrase) });
    IDX = next;
    console.log('[sem] reindexed: ' + IDX.products.length + ' products, ' + IDX.faqs.length + ' faqs, ' + IDX.intents.length + ' intent examples');
    res.json({ ok: true, counts: { products: IDX.products.length, faqs: IDX.faqs.length, categories: IDX.categories.length, intents: IDX.intents.length } });
  } catch (e) { res.json({ ok: false, error: e.message }); }
});

// Closest knowledge to a message: best product, best FAQ, and a voted intent.
app.post('/match', async (req, res) => {
  try {
    if (!ready) return res.json({ ok: false, error: 'not_ready' });
    const msg = String((req.body && req.body.message) || '').slice(0, 512).trim();
    if (!msg) return res.json({ ok: true, product: null, faq: null, intent: null });
    const qv = await embed(msg);

    const bp = top(qv, IDX.products);
    const bpN = topN(qv, IDX.products, 2);
    const bf = top(qv, IDX.faqs);
    const bfN = topN(qv, IDX.faqs, 2);

    // intent = highest summed similarity among the 5 nearest intent example phrases
    let intent = null, iscore = 0;
    if (IDX.intents.length) {
      const near = topN(qv, IDX.intents, 5);
      const votes = {}; near.forEach(x => { votes[x.it.intent] = (votes[x.it.intent] || 0) + x.s; });
      for (const k in votes) if (votes[k] > iscore) { iscore = votes[k]; intent = k; }
      iscore = near[0] ? near[0].s : 0;
    }

    res.json({
      ok: true,
      product: bp ? { id: bp.it.id, name: bp.it.name, cat_slug: bp.it.cat_slug, score: +bp.s.toFixed(4), margin: +(bp.s - ((bpN[1] && bpN[1].s) || 0)).toFixed(4) } : null,
      faq: bf ? { id: bf.it.id, productId: bf.it.productId, q: bf.it.q, a: bf.it.a, score: +bf.s.toFixed(4), margin: +(bf.s - ((bfN[1] && bfN[1].s) || 0)).toFixed(4) } : null,
      intent: intent ? { name: intent, score: +iscore.toFixed(4) } : null
    });
  } catch (e) { res.json({ ok: false, error: e.message }); }
});

app.listen(PORT, '127.0.0.1', () => console.log('[sem] listening on 127.0.0.1:' + PORT));
load();
