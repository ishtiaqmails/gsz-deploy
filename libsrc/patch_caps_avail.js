'use strict';
/* Capabilities rename + per-plan availability note (adminCatalog.js):
   - product capability "has_household" slot becomes Netflix System (nf_enabled); req_otp = Login Code;
     has_link/link_url = Get Link (unchanged columns, relabeled in the UI)
   - product-level geo_note is no longer written by the model (preserved for existing rows); availability
     note is now per-plan (product_plans.avail_note), read + saved per plan.
   Precise, idempotent string patches against the current model.json + model-save. */
const fs = require('fs'), path = require('path');
const ROOT = process.argv[2]; if (!ROOT) { console.error('usage: node patch_caps_avail.js <ROOT>'); process.exit(1); }
const file = path.join(ROOT, 'routes/adminCatalog.js');
let s = fs.readFileSync(file, 'utf8');
let n = 0;
function rep(oldStr, newStr, label){
  if (s.indexOf(newStr) >= 0) { console.log(label + ': present (skip)'); return; }
  if (s.indexOf(oldStr) >= 0) { s = s.replace(oldStr, newStr); n++; console.log(label + ': ok'); }
  else { console.log(label + ': ANCHOR MISSING'); }
}

/* capabilities: has_household -> nf_enabled (from b.netflix) */
rep("const most_selling = !!b.most_selling, req_otp = !!b.req_otp, has_household = !!b.has_household, has_link = !!b.has_link;",
    "const most_selling = !!b.most_selling, req_otp = !!b.req_otp, nf_enabled = !!b.netflix, has_link = !!b.has_link;", "caps var");

/* drop product geo_note var */
rep("const short_desc = (b.short_desc || '').trim(), long_desc = (b.long_desc || '').trim(), geo_note = (b.geo_note || '').trim();",
    "const short_desc = (b.short_desc || '').trim(), long_desc = (b.long_desc || '').trim();", "geo var");

/* products UPDATE query + values */
rep("name=$1,category_id=$2,short_desc=$3,long_desc=$4,geo_note=$5,most_selling=$6,req_otp=$7,has_household=$8,has_link=$9,link_url=$10 WHERE id=$11",
    "name=$1,category_id=$2,short_desc=$3,long_desc=$4,most_selling=$5,req_otp=$6,nf_enabled=$7,has_link=$8,link_url=$9 WHERE id=$10", "prod UPDATE q");
rep("[name, category_id, short_desc, long_desc, geo_note, most_selling, req_otp, has_household, has_link, link_url, id]",
    "[name, category_id, short_desc, long_desc, most_selling, req_otp, nf_enabled, has_link, link_url, id]", "prod UPDATE v");

/* products INSERT query + values */
rep("INSERT INTO products(slug,category_id,name,short_desc,long_desc,geo_note,most_selling,req_otp,has_household,has_link,link_url,active,hidden,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,true,false,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id",
    "INSERT INTO products(slug,category_id,name,short_desc,long_desc,most_selling,req_otp,nf_enabled,has_link,link_url,active,hidden,sort) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,true,false,COALESCE((SELECT MAX(sort)+1 FROM products),1)) RETURNING id", "prod INSERT q");
rep("[slug, category_id, name, short_desc, long_desc, geo_note, most_selling, req_otp, has_household, has_link, link_url]",
    "[slug, category_id, name, short_desc, long_desc, most_selling, req_otp, nf_enabled, has_link, link_url]", "prod INSERT v");

/* model.json products SELECT: has_household -> nf_enabled */
rep("most_selling,req_otp,has_household,has_link,link_url FROM products",
    "most_selling,req_otp,nf_enabled,has_link,link_url FROM products", "model.json prod SELECT");

/* per-plan avail_note */
rep("avail_from,avail_until,popular,nf_portal_product_id FROM product_plans",
    "avail_from,avail_until,popular,nf_portal_product_id,avail_note FROM product_plans", "model.json plan SELECT");
rep("const nfpid = source === 'portal' ? (parseInt(pl.nf_portal_product_id, 10) || null) : null;",
    "const nfpid = source === 'portal' ? (parseInt(pl.nf_portal_product_id, 10) || null) : null;\n        const anote = (pl.avail_note || '').trim() || null;", "anote var");
rep("popular=$18,sort=$19,nf_portal_product_id=$20 WHERE id=$21 AND product_id=$22 RETURNING id',",
    "popular=$18,sort=$19,nf_portal_product_id=$20,avail_note=$21 WHERE id=$22 AND product_id=$23 RETURNING id',", "plan UPDATE q");
rep("pop, i, nfpid, existingId, id]);",
    "pop, i, nfpid, anote, existingId, id]);", "plan UPDATE v");
rep("popular,sort,nf_portal_product_id) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20,$21) RETURNING id',",
    "popular,sort,nf_portal_product_id,avail_note) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14::jsonb,$15::jsonb,$16::jsonb,$17,$18,$19,$20,$21,$22) RETURNING id',", "plan INSERT q");
rep("au, pop, i, nfpid]);",
    "au, pop, i, nfpid, anote]);", "plan INSERT v");

if (n) fs.writeFileSync(file, s);
console.log('CAPS-AVAIL OK (' + n + ' changes)');
