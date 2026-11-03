GSZ=/opt/gsz; cd $GSZ
echo "===== lib/emails.js : transport / provider / sender ====="
grep -nE "nodemailer|createTransport|brevo|sendinblue|smtp|api.?key|host|port|secure|from:|replyTo|EMAIL_|MAIL_|BREVO|SMTP|sendTransac|api.brevo|fetch\(|require\(" lib/emails.js | head -45
echo
echo "===== email env keys present (values hidden) ====="
grep -nE "BREVO|SMTP|MAIL|EMAIL|SENDER|FROM|SIB_|API_KEY" /opt/gsz/.env 2>/dev/null | sed -E 's/=.*/=<hidden>/'
echo
echo "===== callers of emails.* (non-backup) ====="
grep -rnE "emails\.[a-zA-Z]+\(|require\(['\"][^'\"]*emails['\"]\)" routes lib 2>/dev/null | grep -v '\.bak' | head -25
echo
echo "===== sender address / from-domain literals ====="
grep -rnoE "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}" lib/emails.js | head
echo DONE
