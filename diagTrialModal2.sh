#!/usr/bin/env bash
# READ-ONLY. Tail of /providers (its res.json) + the modal renderFields/submit region.
Z=/opt/zayron; cd "$Z"
echo "### /providers tail — the res.json (trial.js 242-310) ###"
sed -n '242,310p' routes/trial.js
echo
echo "### ztrial.js renderFields + submit (197-290) ###"
sed -n '197,290p' public/ztrial.js
echo DONE
