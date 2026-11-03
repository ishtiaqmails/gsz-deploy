GSZ=/opt/gsz
F=$GSZ/views/admin/_shell_top.ejs
B=$GSZ/views/admin/_shell_bottom.ejs
echo "===== _shell_top.ejs pseudo/label/thead rules ====="
grep -nE ":before|::before|content:|thead|attr\(|data-label|nth-child|setAttribute" "$F"
echo
echo "===== _shell_bottom.ejs pseudo/label/thead rules ====="
grep -nE ":before|::before|content:|thead|attr\(|data-label|nth-child|setAttribute" "$B" 2>/dev/null
echo
echo "===== linked css / stylesheet refs in shell ====="
grep -nE "<link|stylesheet|\.css" "$F" "$B" 2>/dev/null
echo
echo "===== global admin css files ====="
ls -la $GSZ/public/*.css $GSZ/public/css/*.css $GSZ/public/admin/*.css 2>/dev/null
grep -rlnE ":before|content:attr|data-label" $GSZ/public 2>/dev/null | head
echo DONE
