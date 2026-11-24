#!/usr/bin/env bash
# READ-ONLY. The GET /trial/start render + how _sessCust is set, to anchor the "skip form when verified" edit.
Z=/opt/zayron; cd "$Z"
echo "### _sessCust / session usage ###"
grep -nE "_sessCust|req\.session|session\.customer" routes/trial.js | head
echo
echo "### GET /trial/start render (lines 53-119) ###"
sed -n '53,119p' routes/trial.js
echo DONE
