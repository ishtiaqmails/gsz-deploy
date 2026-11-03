GSZ=/opt/gsz
echo "===== _shell_bottom.ejs lines 10-55 (auto-label JS) ====="
sed -n '10,55p' $GSZ/views/admin/_shell_bottom.ejs
echo
echo "===== _shell_top.ejs lines 125,145 (.rsp media block) ====="
sed -n '125,145p' $GSZ/views/admin/_shell_top.ejs
echo
echo "===== which admin views already carry class=rsp ====="
grep -rln 'class="rsp"' $GSZ/views/admin/*.ejs 2>/dev/null
echo
echo "===== which admin views have their OWN mobile reflow (thead{display:none}) ====="
grep -rlnE 'thead\{display:none\}|thead \{display:none\}' $GSZ/views/admin/*.ejs 2>/dev/null
echo DONE
