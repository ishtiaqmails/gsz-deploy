#!/usr/bin/env bash
# gsz-sweep8 : make the product savings-badge baseline demo-safe.
# A short paid demo (e.g. "1 Day Demo") has a huge per-month rate and was
# hijacking the savings baseline, inflating every plan's "Save X%". Fix: only
# plans of >= 1 month may set the baseline. Sub-month/demo plans are ignored
# for the baseline and (as before) show no badge themselves.
set -e
cd /opt/gsz
F=views/product.ejs

if grep -q 'mo>=1&&pl.price>0' "$F"; then
  echo "sweep8 already applied (demo-safe baseline present)"; exit 0
fi
if ! grep -q 'mo>0&&pl.price>0' "$F"; then
  echo "ERROR: expected baseline pattern 'mo>0&&pl.price>0' not found in $F — no change made"; exit 1
fi

cp "$F" /opt/gsz/.gsz-prodsave-bak
sed -i 's/mo>0&&pl\.price>0/mo>=1\&\&pl.price>0/g' "$F"

# validate the template still compiles; revert on failure
if ! node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" 2>/tmp/ejserr; then
  echo "EJS compile FAILED — reverting, no restart:"; cat /tmp/ejserr
  cp /opt/gsz/.gsz-prodsave-bak "$F"
  exit 1
fi

# confirm exactly the intended change is present
grep -q 'mo>=1&&pl.price>0' "$F" || { echo "patch did not apply — reverting"; cp /opt/gsz/.gsz-prodsave-bak "$F"; exit 1; }

pm2 restart gsz
echo "DONE: savings baseline now ignores sub-month (demo) plans"
