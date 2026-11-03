GSZ=/opt/gsz; cd $GSZ
echo "===== checkout.js 200-300 (customer WA + events + delays) ====="
sed -n '200,300p' routes/checkout.js
echo
echo "===== where deliver() is called + order_received + delays ====="
grep -rnE "order_received|whatsapp\.order|require\('.*deliver|deliver\(|deliverOrder|delay_seconds|event===|event ===" routes/checkout.js | head -40
echo DONE
