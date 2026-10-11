'use strict';
/* Thread products.renewable through the NEW product model backend (routes/adminCatalog.js):
   - model.json SELECT returns renewable (so Edit loads the toggle state)
   - model-save UPDATE + INSERT persist renewable (from collect()'s b.renewable)
   Uses literal split/join (no regex, no $-replacement pitfalls). Idempotent; hard-fails
   if a required anchor is missing so nothing half-applies. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_renewmodel.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');
const miss = [];
function sub(find, repl, name, already) {
  if (s.indexOf(already) >= 0) { console.log(name + ': already (skip)'); return; }
  if (s.indexOf(find) >= 0) { s = s.split(find).join(repl); console.log(name + ': ok'); }
  else miss.push(name);
}
// 1) capability/flag var decl
sub("nf_enabled = !!b.netflix, has_link = !!b.has_link;",
    "nf_enabled = !!b.netflix, has_link = !!b.has_link, renewable = !!b.renewable;",
    "var decl", "renewable = !!b.renewable");
// 2) UPDATE query tail
sub("link_url=$9 WHERE id=$10", "link_url=$9,renewable=$10 WHERE id=$11", "update q", "renewable=$10 WHERE id=$11");
// 3) UPDATE params tail
sub("has_link, link_url, id]", "has_link, link_url, renewable, id]", "update params", "link_url, renewable, id]");
// 4) INSERT query (columns + placeholders)
sub("has_link,link_url,active,hidden,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,true,false",
    "has_link,link_url,renewable,active,hidden,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,true,false",
    "insert q", "link_url,renewable,active,hidden,sort)");
// 5) INSERT params
sub("has_link, link_url]", "has_link, link_url, renewable]", "insert params", "link_url, renewable]");
// 6) model.json product SELECT
sub("link_url FROM products WHERE id=$1", "link_url,renewable FROM products WHERE id=$1", "model.json select", "link_url,renewable FROM products WHERE id=$1");

if (miss.length) { console.error('PATCH FAILED — anchors not found: ' + miss.join(', ')); process.exit(2); }
fs.writeFileSync(file, s);
console.log('RENEWMODEL OK');
