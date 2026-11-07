cd /opt/gsz
echo "===== fetch.js (player_api puller) ====="
cat -n lib/iptv/fetch.js
echo
echo "===== worker.js lines 36-80 (count store) ====="
sed -n '36,80p' lib/iptv/worker.js
echo
echo "===== m3u.js: series classification/counting ====="
grep -nE "series|episode|Series|group-title|classif|kind|type ?[:=]|push\(" lib/iptv/m3u.js | head -40
echo DONE
