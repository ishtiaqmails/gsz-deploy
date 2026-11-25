#!/usr/bin/env bash
# stepGszCleanBackups — archive + remove stale editor/backup files in /opt/gsz (*.xbak*, *.bak, *.bak-*, *.bak.*,
# *.orig, *~). Excludes node_modules, .git, and .retired (my deploy backups stay). The app isn't restarted — these
# files aren't loaded. Everything removed is first tarred into /opt/gsz/.retired so it's fully recoverable.
set -e
G=/opt/gsz; cd "$G"
TS=$(date +%s); mkdir -p "$G/.retired"
mapfile -t FILES < <(find "$G" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.retired/*' \
  \( -name '*.xbak*' -o -name '*.bak' -o -name '*.bak-*' -o -name '*.bak.*' -o -name '*.orig' -o -name '*~' \) -type f | sort)
echo "found ${#FILES[@]} backup file(s):"
if [ "${#FILES[@]}" -eq 0 ]; then echo "(nothing to clean)"; exit 0; fi
du -ch "${FILES[@]}" | tail -1
printf '%s\n' "${FILES[@]}" | sed "s#^$G/#  #"
ARC="$G/.retired/cleanup-backups-$TS.tar.gz"
tar -czf "$ARC" -C "$G" $(printf '%s\n' "${FILES[@]}" | sed "s#^$G/##") 2>/dev/null
echo "archived -> $ARC ($(du -h "$ARC" | cut -f1))"
rm -f "${FILES[@]}"
LEFT=$(find "$G" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.retired/*' \
  \( -name '*.xbak*' -o -name '*.bak' -o -name '*.bak-*' -o -name '*.bak.*' -o -name '*.orig' -o -name '*~' \) -type f | wc -l)
echo "removed ${#FILES[@]} file(s); remaining backup files: ${LEFT}"
HC=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3900/" 2>/dev/null || echo 000)
echo "gsz still serving: http=${HC}"
echo "DONE: /opt/gsz cleaned. Recoverable from ${ARC} if ever needed."
