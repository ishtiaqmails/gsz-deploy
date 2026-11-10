#!/usr/bin/env bash
# gsz-sweep11 : homepage stats -> compact premium "trust bar", and remove the
# empty space above/below it. Clean IN-PLACE edits (no override layers):
#   - Galaxy Hub (.cth) bottom margin 38px -> 16px   (gap above)
#   - .stats-in -> contained glass card, smaller numbers, tighter padding
#   - .stats + .section top padding reduced           (gap below)
set -e
cd /opt/gsz
A=public/css/app.css
C=views/partials/customer_tools.ejs

if grep -q 'max-width:680px;margin:0 auto;padding:16px 12px' "$A"; then
  echo "sweep11 already applied"; exit 0
fi

cp "$A" /opt/gsz/.gsz-appcss-bak
cp "$C" /opt/gsz/.gsz-cth-bak

cat > /tmp/gsz_edit11.js <<'JS'
const fs=require('fs');
function repl(file,pairs){
  let s=fs.readFileSync(file,'utf8');
  for(const [a,b] of pairs){
    const n=s.split(a).length-1;
    if(n!==1){ console.error('EXPECTED 1 MATCH, got '+n+' in '+file+' for: '+a.slice(0,70)); process.exit(3); }
    s=s.replace(a,b);
  }
  fs.writeFileSync(file,s);
}
repl('views/partials/customer_tools.ejs',[
  ['.cth{max-width:1200px;margin:34px auto 38px;padding:0 20px}',
   '.cth{max-width:1200px;margin:34px auto 16px;padding:0 20px}']
]);
repl('public/css/app.css',[
  ['.stats{border-bottom:1px solid var(--line)}',
   '.stats{padding-top:2px}'],
  ['.stats-in{display:grid;grid-template-columns:repeat(3,1fr);gap:0;padding:26px 0}',
   '.stats-in{display:flex;max-width:680px;margin:0 auto;padding:16px 12px;gap:0;background:linear-gradient(180deg,rgba(255,255,255,.045),rgba(255,255,255,.015));border:1px solid var(--line);border-radius:18px;box-shadow:inset 0 1px 0 rgba(255,255,255,.05),0 20px 44px -34px rgba(0,0,0,.9)}'],
  ['.stat{text-align:center;padding:4px 16px;position:relative}',
   '.stat{flex:1;min-width:0;text-align:center;padding:4px 14px;position:relative}'],
  ['.stat b{display:block;font-family:var(--display);font-weight:800;font-size:clamp(26px,3.4vw,38px);letter-spacing:-.02em;line-height:1}',
   '.stat b{display:block;font-family:var(--display);font-weight:800;font-size:clamp(22px,2.8vw,30px);letter-spacing:-.02em;line-height:1}'],
  ['.stat .lbl{display:block;margin-top:7px;color:var(--muted);font-size:13.5px;font-weight:500}',
   '.stat .lbl{display:block;margin-top:6px;color:var(--muted);font-size:12.5px;font-weight:500;line-height:1.3}'],
  ['@media(max-width:560px){.stats-in{padding:18px 0}.stat{padding:4px 8px}.stat .lbl{font-size:12px}}',
   '@media(max-width:560px){.stats-in{padding:14px 8px}.stat{padding:4px 7px}.stat .lbl{font-size:11.5px}}\n.stats+.section{padding-top:clamp(16px,2.2vw,24px)}']
]);
console.log('edits applied');
JS

node /tmp/gsz_edit11.js || { echo "edit failed — reverting"; cp /opt/gsz/.gsz-appcss-bak "$A"; cp /opt/gsz/.gsz-cth-bak "$C"; exit 1; }

if ! node -e "require('ejs').compile(require('fs').readFileSync('$C','utf8'),{filename:'$C'})" 2>/tmp/ejserr; then
  echo "EJS compile FAILED — reverting:"; cat /tmp/ejserr; cp /opt/gsz/.gsz-appcss-bak "$A"; cp /opt/gsz/.gsz-cth-bak "$C"; exit 1
fi

# cache-bust app.css so browsers fetch the updated CSS
NV=$(date +%s)
for F in $(grep -rlE 'app\.css\?v=' views --include=*.ejs); do
  sed -i -E "s#(app\.css\?v=)[0-9]+#\1$NV#g" "$F"
done

pm2 restart gsz
echo "DONE: compact premium stats bar + tighter spacing (app.css v=$NV)"
