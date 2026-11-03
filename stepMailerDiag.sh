GSZ=/opt/gsz; cd $GSZ
echo "===== non-secret mail config (user/pass/key hidden) ====="
grep -E "^GSZ_SMTP_HOST=|^GSZ_SMTP_PORT=|^GSZ_SMTP_FROM=|^GSZ_SMTP_SECURE=" /opt/gsz/.env
echo
echo "===== transport file(s) ====="
grep -rln "createTransport\|api\.brevo\|sendTransac\|smtp-relay\|GSZ_SMTP_HOST\|BREVO_API_KEY" lib routes server.js 2>/dev/null | grep -v '\.bak'
echo
echo "===== send function body ====="
for F in $(grep -rln "createTransport\|sendTransac\|GSZ_SMTP_HOST\|BREVO_API_KEY" lib routes server.js 2>/dev/null | grep -v '\.bak'); do
  echo "---- $F ----"
  grep -nE "createTransport|nodemailer|sendMail|sendTransac|api\.brevo|GSZ_SMTP|BREVO_API|from|transporter|host|port|auth|secure|function.*[Mm]ail" "$F" | head -30
done
echo DONE
