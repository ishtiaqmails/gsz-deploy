#!/usr/bin/env bash
# stepCleanup2.sh — sweep timestamped backup cruft from the LIVE app only.
# Removes files whose name ends in .bak.<digits> or .xbak.<digits> (the step-script + editor backups),
# plus any leftover .gszm_* temp validators. Never touches a live file, node_modules, or .git.
set -uo pipefail
GSZ=/opt/gsz
cd "$GSZ" || { echo "no $GSZ"; exit 1; }

echo "==> scanning $GSZ for backup cruft (*.bak.<ts>, *.xbak.<ts>)"
mapfile -t FILES < <(find . -type f -regextype posix-extended -regex '.*\.(bak|xbak)\.[0-9]+$' -not -path './node_modules/*' -not -path './.git/*')
N=${#FILES[@]}
echo "   found: $N"
if [ "$N" -gt 0 ]; then
  echo "   sample:"
  printf '     %s\n' "${FILES[@]:0:10}"
  [ "$N" -gt 10 ] && echo "     ... and $((N-10)) more"
  SZ=$(du -ch "${FILES[@]}" 2>/dev/null | tail -1 | cut -f1)
  rm -f -- "${FILES[@]}"
  echo "   removed $N files (${SZ:-?} reclaimed)"
fi

# leftover temp validators from our step scripts (safe; we always rm these, this catches any stragglers)
rm -f .gszm_*.js .gszm_* 2>/dev/null || true

LEFT=$(find . -type f -regextype posix-extended -regex '.*\.(bak|xbak)\.[0-9]+$' -not -path './node_modules/*' -not -path './.git/*' | wc -l)
echo "==> remaining backup files (expect 0): $LEFT"
echo "DONE — backups swept. Only timestamped .bak/.xbak files were removed; every live file is untouched."
