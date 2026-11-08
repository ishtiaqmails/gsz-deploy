echo "=== tailscale on VPS? ==="
which tailscale >/dev/null 2>&1 && echo "tailscale INSTALLED" || echo "tailscale NOT installed"
tailscale status 2>&1 | head -8
echo "VPS tailscale IP:"; tailscale ip -4 2>/dev/null || echo "(none)"
echo
echo "=== ssh tools on VPS ==="
which ssh autossh 2>/dev/null
echo
echo "=== VPS public IP ==="
curl -s -4 --max-time 8 ifconfig.me 2>/dev/null; echo
echo DONE
