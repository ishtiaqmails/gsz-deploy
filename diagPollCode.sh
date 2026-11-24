#!/usr/bin/env bash
# READ-ONLY. Dumps botQueue.js (pollWebTrial) + gszApi.getProducts so we can fix the status flip + array bug.
Z=/opt/zayron; cd "$Z"
echo "### lib/botQueue.js (full) ###"
cat -n lib/botQueue.js
echo
echo "### lib/gszApi.js — getProducts ###"
grep -n "getProducts\|function getProducts\|products\|return" lib/gszApi.js | head -40
echo
echo "### getProducts function body ###"
awk '/getProducts/{f=1} f{print NR": "$0} f&&/^\s*}/{c++; if(c>=1 && /^  }/){exit}}' lib/gszApi.js | head -40
echo DONE
