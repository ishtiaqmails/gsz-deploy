#!/usr/bin/env bash
# gsz-sweep26 : slow the mobile top-strip rotation from 3.5s to 7s per slide.
# (Desktop shows both halves at once and never rotates — this only affects phones.)
set -e
cd /opt/gsz
F=views/partials/top_strip.ejs
cp "$F" /opt/gsz/.gsz-s26-ts.bak

node -e '
const fs=require("fs"); const f="views/partials/top_strip.ejs"; let s=fs.readFileSync(f,"utf8");
const a="},3500);})();"; const b="},7000);})();";
const n=s.split(a).length-1; if(n!==1){ console.error("EXPECT 1 interval, got "+n); process.exit(3); }
fs.writeFileSync(f, s.replace(a,b)); console.log("rotation slowed 3.5s -> 7s");
' || { echo "edit failed — reverting"; cp /opt/gsz/.gsz-s26-ts.bak "$F"; exit 1; }

node -e "require('ejs').compile(require('fs').readFileSync('$F','utf8'),{filename:'$F'})" || { echo "EJS error — reverting"; cp /opt/gsz/.gsz-s26-ts.bak "$F"; exit 1; }

pm2 restart gsz
echo "DONE: mobile strip rotation slowed to 7s per slide."
