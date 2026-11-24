#!/usr/bin/env bash
# READ-ONLY. The exact sections to anchor forgot-password + change-number.
Z=/opt/zayron; cd "$Z"
echo "### signup + verify + code-gen + resend (104-215) ###"
sed -n '104,215p' routes/account.js
echo
echo "### login GET + POST + me + logout (240-300) ###"
sed -n '240,300p' routes/account.js
echo
echo "### dashPage / nav item helper (330,380) ###"
sed -n '330,380p' routes/account.js
echo
echo "### settings page (590,615) ###"
sed -n '590,615p' routes/account.js
echo DONE
