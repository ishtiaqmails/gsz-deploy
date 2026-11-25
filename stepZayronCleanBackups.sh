#!/usr/bin/env bash
# stepZayronCleanBackups — archive + remove stale editor/backup files in /opt/zayron and /opt/zayron-otp
# (*.xbak*, *.bak, *.bak-*, *.bak.*, *.orig, *~, *.baileys.bak.*). Excludes node_modules, .git, .retired.
# No app restart (files aren't loaded). Everything is tarred into each app's .retired first, so it's recoverable.
set -e
clean_dir(){
  local D="$1"; local PORT="$2"
  [ -d "$D" ] || { echo "== $D not found, skipping =="; return; }
  cd "$D"; local TS=$(date +%s); mkdir -p "$D/.retired"
  echo "================= $D ================="
  mapfile -t FILES < <(find "$D" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.retired/*' \
    \( -name '*.xbak*' -o -name '*.bak' -o -name '*.bak-*' -o -name '*.bak.*' -o -name '*.baileys.bak.*' -o -name '*.orig' -o -name '*~' \) -type f | sort)
  echo "found ${#FILES[@]} backup file(s)"
  if [ "${#FILES[@]}" -eq 0 ]; then echo "(nothing to clean)"; else
    du -ch "${FILES[@]}" | tail -1
    printf '%s\n' "${FILES[@]}" | sed "s#^$D/#  #"
    local ARC="$D/.retired/cleanup-backups-$TS.tar.gz"
    tar -czf "$ARC" -C "$D" $(printf '%s\n' "${FILES[@]}" | sed "s#^$D/##") 2>/dev/null
    echo "archived -> $ARC ($(du -h "$ARC" | cut -f1))"
    rm -f "${FILES[@]}"
    local LEFT=$(find "$D" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.retired/*' \
      \( -name '*.xbak*' -o -name '*.bak' -o -name '*.bak-*' -o -name '*.bak.*' -o -name '*.baileys.bak.*' -o -name '*.orig' -o -name '*~' \) -type f | wc -l)
    echo "removed ${#FILES[@]} file(s); remaining: ${LEFT}"
  fi
  if [ -n "$PORT" ]; then echo "app still serving: http=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/" 2>/dev/null || echo 000)"; fi
}
clean_dir /opt/zayron 3500
clean_dir /opt/zayron-otp ""
echo
echo "pm2 zayron-otp status: $(pm2 jlist 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{const p=JSON.parse(d).find(x=>x.name==='zayron-otp');console.log((p&&p.pm2_env&&p.pm2_env.status)||'unknown');}catch(e){console.log('unknown');}});" 2>/dev/null)"
echo "DONE: zayron.tv apps cleaned. Recoverable from each app's .retired/ tarball if ever needed."
