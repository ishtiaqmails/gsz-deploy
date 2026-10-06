#!/usr/bin/env bash
# Tests whether a pm2 restart wipes new css files, and looks for a build step.
APP=/opt/gsz
echo '/*carttest*/.gsztest-xyz{color:red}' > "$APP/public/css/__t.css"
echo 'TESTJS' > "$APP/public/js/__t.js"
echo "BEFORE restart:"; ls "$APP/public/css/__t.css" "$APP/public/js/__t.js" 2>&1
pm2 restart gsz --update-env >/dev/null 2>&1; sleep 3
echo "AFTER restart:"; ls "$APP/public/css/__t.css" "$APP/public/js/__t.js" 2>&1
echo "curl css: $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/static/css/__t.css)"
echo "curl js : $(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:3900/static/js/__t.js)"
echo
echo "=== package.json scripts ==="; node -e 'try{console.log(JSON.stringify(require("/opt/gsz/package.json").scripts||{},null,2))}catch(e){console.log("(no package.json)")}'
echo "=== pm2 process (script / cwd) ==="; pm2 describe gsz 2>/dev/null | grep -iE "script path|exec cwd|script args|node args" | head
echo "=== server.js: build/copy/css hints ==="; grep -nE "copy|build|css|mkdir|writeFile|rmSync|unlink|rimraf|concat|clean|emptyDir" "$APP/server.js" 2>/dev/null | head -30
echo "=== any prestart/build js referencing css ==="; grep -rnE "public/css|/css|\.css" "$APP/server.js" 2>/dev/null | head -20
rm -f "$APP/public/css/__t.css" "$APP/public/js/__t.js"
echo "== DONE =="
