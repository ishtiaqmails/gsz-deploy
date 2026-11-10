#!/usr/bin/env bash
# gsz-sweep10 : remove the "How it works / Up and running in three steps"
# section (incl. the "Get your IPTV panel" button) from the resellers page.
set -e
cd /opt/gsz
F=views/resellers.ejs

if ! grep -q 'Up and running in three steps' "$F"; then
  echo "already removed (How it works block absent)"; exit 0
fi

cp "$F" /opt/gsz/.gsz-resellers-how-bak

node -e '
const fs=require("fs");
const f="views/resellers.ejs";
let s=fs.readFileSync(f,"utf8");
const marker="Up and running in three steps";
const i=s.indexOf(marker);
if(i<0){console.log("marker gone");process.exit(0);}
const start=s.lastIndexOf("<section",i);
let end=s.indexOf("</section>",i);
if(start<0||end<0){console.error("boundaries not found");process.exit(2);}
end+="</section>".length;
fs.writeFileSync(f,s.slice(0,start)+s.slice(end));
console.log("cut block ["+start+","+end+"]");
'

# validate template still compiles; revert on failure
if ! node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" 2>/tmp/ejserr; then
  echo "EJS compile FAILED — reverting:"; cat /tmp/ejserr; cp /opt/gsz/.gsz-resellers-how-bak "$F"; exit 1
fi
if grep -q 'Up and running in three steps' "$F"; then
  echo "block still present — reverting"; cp /opt/gsz/.gsz-resellers-how-bak "$F"; exit 1
fi

pm2 restart gsz
echo "DONE: removed 'How it works' section from the resellers page"
