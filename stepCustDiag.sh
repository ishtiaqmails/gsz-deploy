GSZ=/opt/gsz; cd "$GSZ" || exit 1; f=views/admin/customers.ejs
echo "===== customers.ejs: reflow CSS / data-label / :before =====" 
grep -nE "@media|:before|data-label|content:attr|#cuTable|\.cu-|display:block|display:flex|display:none" "$f" | head -60
echo
echo "===== table head + row template (100-150) ====="
sed -n '100,150p' "$f"
echo DONE
