#!/usr/bin/env bash
# READ-ONLY. The /providers JSON builder (to add verifiedPhone) + the modal's number-entry/submit code.
Z=/opt/zayron; cd "$Z"
echo "### /trial/providers builder (195-245) ###"
sed -n '195,245p' routes/trial.js
echo
echo "### ztrial.js — number entry / submit / otp anchors ###"
grep -nE "trial/start|phone|getE164|fetch\(|otp|verify|ZPhone|number|step|screen|render|html|innerHTML" public/ztrial.js | head -50
echo DONE
