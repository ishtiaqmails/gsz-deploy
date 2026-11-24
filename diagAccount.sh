#!/usr/bin/env bash
# READ-ONLY. Account routes map + OTP/verify + settings render, to anchor forgot-password & change-number.
Z=/opt/zayron; cd "$Z"
echo "### file size ###"; wc -l routes/account.js
echo "### all routes + OTP/verify/phone_verified/settings anchors ###"
grep -nE "router\.(get|post)|otp_outbox|phone_verified|signup_otp_on|_isOtpOn|verifyForm|Settings|settings|Forgot|forgot|pass_hash|bcrypt|normPhone" routes/account.js | head -80
echo DONE
