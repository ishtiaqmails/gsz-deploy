#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### order_detail.ejs — top (shell include) ###"
sed -n '1,4p' views/admin/order_detail.ejs
echo "### order_detail.ejs — proof block (48-66), with line numbers ###"
sed -n '48,66p' views/admin/order_detail.ejs | cat -A | sed -n '1,30p'
