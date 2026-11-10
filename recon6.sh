#!/usr/bin/env bash
# recon6 : READ-ONLY. Finds the footer's social-icons + WhatsApp-channel markup
# (to remove) and how social_links / wa_channel_url are rendered. Changes nothing.
cd /opt/gsz

echo "=== footer partial(s) ==="
grep -rln 'class="ft\|<footer\|ft-social\|ft-soc\|footer' views --include=*.ejs | grep -vi '\.bak'

echo; echo "=== where social_links / wa_channel_url / 'Join our WhatsApp Channel' render ==="
grep -rn "social_links\|wa_channel_url\|Join our WhatsApp Channel\|waChannel\|channelUrl" views --include=*.ejs | grep -vi '\.bak' | head -30

echo; echo "=== footer social block context ==="
F=$(grep -rln 'wa_channel_url\|social_links' views/partials/*.ejs 2>/dev/null | grep -vi '\.bak' | head -1)
echo "file: $F"
if [ -n "$F" ]; then grep -n 'social\|channel\|ft-soc\|<footer\|class="ft\|Join our' "$F" | head -25; fi

echo; echo "=== recon6 done ==="
