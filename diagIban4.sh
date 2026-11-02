#!/usr/bin/env bash
cd /opt/gsz || { echo "no /opt/gsz"; exit 1; }
echo "### which files render the quick-buy modal ###"
grep -rlnE "Copy number|Choose type|Send .* to:|Upload payment receipt" views public 2>/dev/null
echo
echo "### matches with context ###"
grep -rnE "Copy number|Choose type|copyNum|Send \$\{|Send .*to:|Title:|Account:" views public 2>/dev/null | grep -viE "node_modules" | head -40
