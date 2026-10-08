#!/usr/bin/env bash
# step196 — fix dead btn-p class on storefront (grey buttons) + bump app.css cache-buster.
# Edits ONLY public/css/app.css + views/partials/store_top.ejs. Admin/invoice btn-p untouched.
set -uo pipefail
GSZ=/opt/gsz
TS=$(date +%Y%m%d-%H%M%S)
cd "$GSZ" || { echo "FATAL: no $GSZ"; exit 1; }

FILES=(public/css/app.css views/partials/store_top.ejs)

# --- backups ---
for f in "${FILES[@]}"; do cp -p "$f" "$f.bak-step196-$TS"; done
echo "backups: *.bak-step196-$TS"

restore(){ echo "!! restoring from backups"; for f in "${FILES[@]}"; do [ -f "$f.bak-step196-$TS" ] && cp -p "$f.bak-step196-$TS" "$f"; done; }
trap 'restore' ERR

# --- write + run patcher ---
PJS=$(mktemp /tmp/patch_step196.XXXXXX.js)
base64 -d > "$PJS" <<'B64EOF'
J3VzZSBzdHJpY3QnOwovKiBzdGVwMTk2IOKAlCBmaXggdGhlIGRlYWQgYGJ0bi1wYCBjbGFzcyBvbiBTVE9SRUZST05UIHBhZ2VzIChncmV5IGJ1dHRvbnMpLgogICBUaGUgc3RvcmVmcm9udCdzIGFwcC5jc3Mgb25seSBkZWZpbmVzIGAuYnRuLXByaW1hcnlgLCBidXQgdGhlIGFjY291bnQvKiBhbmQKICAgdHJpYWxzIHBhZ2VzIHdlcmUgYXV0aG9yZWQgd2l0aCBgYnRuLXBgICh0aGUgc2FtZSBuYW1lIHRoZSBhZG1pbiBzaGVsbCB1c2VzCiAgIGZvciBpdHMgcHJpbWFyeSkuIFJlc3VsdDogU2lnbiBpbiAvIENyZWF0ZSBhY2NvdW50IC8gU2VuZCByZXNldCBjb2RlIC8gQ2hhbmdlCiAgIHBhc3N3b3JkIC8gVmVyaWZ5IGVtYWlsIC8gcmVuZXcgKyBhY2NvdW50IGFjdGlvbiBidXR0b25zIHJlbmRlciBhcyB0aGUKICAgYnJvd3NlcidzIG5hdGl2ZSBncmV5IGluc3RlYWQgb2YgdGhlIGdyYWRpZW50IGJyYW5kIGJ1dHRvbi4KICAgRml4IChjb25zb2xpZGF0ZWQsIG5vdCBsYXllcmVkKTogZXh0ZW5kIGFwcC5jc3MncyBleGlzdGluZyBgLmJ0bi1wcmltYXJ5YAogICBzZWxlY3RvcnMgdG8gQUxTTyBtYXRjaCBgLmJ0bi1wYCwgc28gb25lIGNsYXNzIG1lYW5zIHByaW1hcnkgYWNyb3NzIHRoZSB3aG9sZQogICBzdG9yZWZyb250IOKAlCBubyBkdXBsaWNhdGUgcnVsZSBibG9jaywgbm8gMTItZmlsZSByZW5hbWUuIEFkbWluIGtlZXBzIGl0cyBvd24KICAgYC5idG4tcGAgKGl0cyBzaGVsbCBkZWZpbmVzIGl0KSBhbmQgaW52b2ljZS5lanMga2VlcHMgaXRzIGxvY2FsIG9uZTsgbmVpdGhlcgogICBpcyB0b3VjaGVkLiBCdW1wIHRoZSBhcHAuY3NzIGNhY2hlLWJ1c3RlciBzbyBicm93c2VycyBwaWNrIGl0IHVwLgogICBJZGVtcG90ZW50LiAqLwpjb25zdCBmcyA9IHJlcXVpcmUoJ2ZzJyk7IGNvbnN0IHBhdGggPSByZXF1aXJlKCdwYXRoJyk7CmNvbnN0IFJPT1QgPSBwcm9jZXNzLmFyZ3ZbMl07IGlmICghUk9PVCkgeyBjb25zb2xlLmVycm9yKCd1c2FnZTogbm9kZSBwYXRjaF9zdGVwMTk2LmpzIDxST09UPicpOyBwcm9jZXNzLmV4aXQoMSk7IH0KZnVuY3Rpb24gcGF0Y2gocmVsLCBlZGl0cykgewogIGNvbnN0IGZpbGUgPSBwYXRoLmpvaW4oUk9PVCwgcmVsKTsgbGV0IHMgPSBmcy5yZWFkRmlsZVN5bmMoZmlsZSwgJ3V0ZjgnKTsKICBmb3IgKGNvbnN0IGUgb2YgZWRpdHMpIHsKICAgIGlmIChzLmluZGV4T2YoZS5ndWFyZCkgPj0gMCkgeyBjb25zb2xlLmxvZygnc2tpcCAoYWxyZWFkeSk6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOyBjb250aW51ZTsgfQogICAgY29uc3QgZmlyc3QgPSBzLmluZGV4T2YoZS5maW5kKTsKICAgIGlmIChmaXJzdCA8IDApIHRocm93IG5ldyBFcnJvcignQU5DSE9SIE1JU1M6ICcgKyByZWwgKyAnIDo6ICcgKyBlLm5hbWUpOwogICAgaWYgKHMuaW5kZXhPZihlLmZpbmQsIGZpcnN0ICsgMSkgPj0gMCkgdGhyb3cgbmV3IEVycm9yKCdBTkNIT1IgTk9UIFVOSVFVRTogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgICBzID0gcy5zbGljZSgwLCBmaXJzdCkgKyBlLnJlcGxhY2UgKyBzLnNsaWNlKGZpcnN0ICsgZS5maW5kLmxlbmd0aCk7CiAgICBjb25zb2xlLmxvZygncGF0Y2hlZDogJyArIHJlbCArICcgOjogJyArIGUubmFtZSk7CiAgfQogIGZzLndyaXRlRmlsZVN5bmMoZmlsZSwgcyk7Cn0KCi8qIC0tLS0tLS0tLS0gcHVibGljL2Nzcy9hcHAuY3NzIDogbWFrZSAuYnRuLXAgYSBzeW5vbnltIG9mIC5idG4tcHJpbWFyeSAtLS0tLS0tLS0tICovCnBhdGNoKCdwdWJsaWMvY3NzL2FwcC5jc3MnLCBbCiAgeyBuYW1lOiAncHJpbWFyeS1iYXNlJywKICAgIGd1YXJkOiAnLmJ0bi1wcmltYXJ5LC5idG4tcHtiYWNrZ3JvdW5kOnZhcigtLWJyYW5kKScsCiAgICBmaW5kOiAnLmJ0bi1wcmltYXJ5e2JhY2tncm91bmQ6dmFyKC0tYnJhbmQpO2NvbG9yOiNmZmY7Ym94LXNoYWRvdzowIDE0cHggMzRweCAtMTJweCByZ2JhKDU5LDEzMCwyNTUsLjkpLDAgMCAwIDFweCByZ2JhKDI1NSwyNTUsMjU1LC4wOCkgaW5zZXR9JywKICAgIHJlcGxhY2U6ICcuYnRuLXByaW1hcnksLmJ0bi1we2JhY2tncm91bmQ6dmFyKC0tYnJhbmQpO2NvbG9yOiNmZmY7Ym94LXNoYWRvdzowIDE0cHggMzRweCAtMTJweCByZ2JhKDU5LDEzMCwyNTUsLjkpLDAgMCAwIDFweCByZ2JhKDI1NSwyNTUsMjU1LC4wOCkgaW5zZXR9JyB9LAogIHsgbmFtZTogJ3ByaW1hcnktaG92ZXInLAogICAgZ3VhcmQ6ICcuYnRuLXByaW1hcnk6aG92ZXIsLmJ0bi1wOmhvdmVye3RyYW5zZm9ybTp0cmFuc2xhdGVZKC0xcHgpO2JveC1zaGFkb3c6MCAxNnB4JywKICAgIGZpbmQ6ICcuYnRuLXByaW1hcnk6aG92ZXJ7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoLTFweCk7Ym94LXNoYWRvdzowIDE2cHggMzBweCAtMTJweCByZ2JhKDQyLDEwOCwyNTUsLjk1KX0nLAogICAgcmVwbGFjZTogJy5idG4tcHJpbWFyeTpob3ZlciwuYnRuLXA6aG92ZXJ7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoLTFweCk7Ym94LXNoYWRvdzowIDE2cHggMzBweCAtMTJweCByZ2JhKDQyLDEwOCwyNTUsLjk1KX0nIH0sCiAgeyBuYW1lOiAncHJpbWFyeS1wb3MnLAogICAgZ3VhcmQ6ICcuYnRuLXByaW1hcnksLmJ0bi1we3Bvc2l0aW9uOnJlbGF0aXZlO292ZXJmbG93OmhpZGRlbn0nLAogICAgZmluZDogJy5idG4tcHJpbWFyeXtwb3NpdGlvbjpyZWxhdGl2ZTtvdmVyZmxvdzpoaWRkZW59JywKICAgIHJlcGxhY2U6ICcuYnRuLXByaW1hcnksLmJ0bi1we3Bvc2l0aW9uOnJlbGF0aXZlO292ZXJmbG93OmhpZGRlbn0nIH0sCiAgeyBuYW1lOiAncHJpbWFyeS1hZnRlcicsCiAgICBndWFyZDogJy5idG4tcHJpbWFyeTo6YWZ0ZXIsLmJ0bi1wOjphZnRlcntjb250ZW50JywKICAgIGZpbmQ6ICcuYnRuLXByaW1hcnk6OmFmdGVye2NvbnRlbnQ6IiI7cG9zaXRpb246YWJzb2x1dGU7dG9wOjA7bGVmdDotNzAlO3dpZHRoOjQwJTtoZWlnaHQ6MTAwJTtwb2ludGVyLWV2ZW50czpub25lOycsCiAgICByZXBsYWNlOiAnLmJ0bi1wcmltYXJ5OjphZnRlciwuYnRuLXA6OmFmdGVye2NvbnRlbnQ6IiI7cG9zaXRpb246YWJzb2x1dGU7dG9wOjA7bGVmdDotNzAlO3dpZHRoOjQwJTtoZWlnaHQ6MTAwJTtwb2ludGVyLWV2ZW50czpub25lOycgfSwKICB7IG5hbWU6ICdwcmltYXJ5LWFmdGVyLWhvdmVyJywKICAgIGd1YXJkOiAnLmJ0bi1wcmltYXJ5OmhvdmVyOjphZnRlciwuYnRuLXA6aG92ZXI6OmFmdGVye29wYWNpdHknLAogICAgZmluZDogJy5idG4tcHJpbWFyeTpob3Zlcjo6YWZ0ZXJ7b3BhY2l0eToxO2FuaW1hdGlvbjpzaGluZSAuOHMgZWFzZSBmb3J3YXJkc30nLAogICAgcmVwbGFjZTogJy5idG4tcHJpbWFyeTpob3Zlcjo6YWZ0ZXIsLmJ0bi1wOmhvdmVyOjphZnRlcntvcGFjaXR5OjE7YW5pbWF0aW9uOnNoaW5lIC44cyBlYXNlIGZvcndhcmRzfScgfQpdKTsKCi8qIC0tLS0tLS0tLS0gdmlld3MvcGFydGlhbHMvc3RvcmVfdG9wLmVqcyA6IGJ1bXAgdGhlIGFwcC5jc3MgY2FjaGUtYnVzdGVyIC0tLS0tLS0tLS0gKi8KcGF0Y2goJ3ZpZXdzL3BhcnRpYWxzL3N0b3JlX3RvcC5lanMnLCBbCiAgeyBuYW1lOiAnY3NzLWJ1c3QnLAogICAgZ3VhcmQ6ICcvc3RhdGljL2Nzcy9hcHAuY3NzP3Y9MjYnLAogICAgZmluZDogJy9zdGF0aWMvY3NzL2FwcC5jc3M/dj0yNScsCiAgICByZXBsYWNlOiAnL3N0YXRpYy9jc3MvYXBwLmNzcz92PTI2JyB9Cl0pOwoKY29uc29sZS5sb2coJ0FMTCBQQVRDSEVTIEFQUExJRUQnKTsK
B64EOF
node "$PJS" "$GSZ"

# --- validate the EJS view compiles ---
node -e "const ejs=require('$GSZ/node_modules/ejs'),fs=require('fs');ejs.compile(fs.readFileSync('$GSZ/views/partials/store_top.ejs','utf8'),{filename:'$GSZ/views/partials/store_top.ejs'});console.log('ejs ok: store_top.ejs');" || { echo 'EJS COMPILE FAILED'; restore; exit 2; }

# --- confirm the alias actually landed in app.css ---
grep -q '.btn-primary,.btn-p{background:var(--brand)' public/css/app.css || { echo 'VERIFY FAILED: btn-p alias not present'; restore; exit 3; }
grep -q 'app.css?v=26' views/partials/store_top.ejs || { echo 'VERIFY FAILED: cache-buster not bumped'; restore; exit 3; }
echo "verify ok: btn-p alias + v=26 present"

trap - ERR

# --- restart + health poll ---
pm2 restart gsz --update-env >/dev/null 2>&1 || pm2 restart gsz >/dev/null 2>&1
ok=0
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/ || true)
  if [ "$code" = "200" ]; then ok=1; echo "health ok (HTTP 200) after ${i} tries"; break; fi
  sleep 0.6
done
[ "$ok" = "1" ] || { echo "HEALTH CHECK FAILED (last code: ${code:-none}) — restoring"; restore; pm2 restart gsz >/dev/null 2>&1; exit 4; }

echo "STEP196 DONE — storefront primary buttons now render the gradient brand."
