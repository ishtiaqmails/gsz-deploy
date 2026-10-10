#!/usr/bin/env bash
# dumpHome — locate home view + show the "Try IPTV free" band and insertion anchors. SMALL output.
GSZ=/opt/gsz; cd "$GSZ" || exit 1
HV=$(grep -rln "Try IPTV free" views/ 2>/dev/null | grep -v '\.bak' | head -1)
echo "HOME VIEW: ${HV:-NOT FOUND}"
[ -z "$HV" ] && { echo "## fallback: views containing 'IPTV' hero ##"; grep -rln "Premium Entertainment\|IPTV Free Trial" views/ 2>/dev/null | grep -v '\.bak'; exit 0; }
echo
echo "## 'Try IPTV free' band block (to remove) ##"
L=$(grep -n "Try IPTV free" "$HV" | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-4)),$((L+14))p" "$HV"
echo
echo "## includes + section anchors + locals (for inserting Quick Access) ##"
grep -nE "<%- *include\(|</section>|class=\"hero|<main|waNumber|session\.customer|session && req\.session\.customer|locals" "$HV" 2>/dev/null | head -30
echo "== dumpHome done =="
