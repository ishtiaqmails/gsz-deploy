GSZ=/opt/gsz; cd "$GSZ" || exit 1
echo "############ FULL order_detail.ejs ############"
cat -n views/admin/order_detail.ejs
echo "############ shell responsive CSS (full rsp + card + content + mbar) ############"
sed -n '125,170p' views/admin/_shell_top.ejs
echo DONE
