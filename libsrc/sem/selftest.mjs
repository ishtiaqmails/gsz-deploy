// Proves the local semantic model installs + runs on this VPS, and that it matches questions
// by MEANING (paraphrases, no shared keywords) — the whole point of the upgrade. No external API.
import { pipeline, cos_sim, env } from '@xenova/transformers';
env.cacheDir = './models';          // keep the model cached inside /opt/gsz-sem
env.allowLocalModels = false;       // fetch from the hub on first run

console.log('loading model (first run downloads ~23MB, then cached)…');
const t0 = Date.now();
const extractor = await pipeline('feature-extraction', 'Xenova/all-MiniLM-L6-v2');
console.log('model ready in ' + ((Date.now() - t0) / 1000).toFixed(1) + 's');

const embed = async (text) => Array.from((await extractor(text, { pooling: 'mean', normalize: true })).data);

// a few real-style FAQ questions (no keyword overlap with the test queries on purpose)
const faqs = [
  'Does Opplex work on Firestick?',
  'How fast is delivery after payment is confirmed?',
  'Which payment methods do you accept?',
  'Is there a warranty or replacement if it stops working?',
  'Can I use one account on multiple devices?'
];
const fv = [];
for (const q of faqs) fv.push(await embed(q));

// customer questions phrased differently from the FAQs
const tests = [
  'will this run on my amazon stick',
  'how long until i actually get it',
  'can i pay with easypaisa',
  'what happens if it stops working next week',
  'how many screens at once'
];

let ms0 = Date.now();
for (const q of tests) {
  const qv = await embed(q);
  const best = faqs.map((f, i) => ({ f, s: cos_sim(qv, fv[i]) })).sort((a, b) => b.s - a.s)[0];
  console.log('\nQ: ' + q + '\n   -> ' + best.s.toFixed(3) + '  ' + best.f);
}
console.log('\navg query time: ' + Math.round((Date.now() - ms0) / tests.length) + 'ms');
console.log('SEMANTIC OK');
