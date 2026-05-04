#!/bin/bash
# Dell Server Health Check
# Usage: ./health-check.sh [local|tailscale]

IP="${1:-local}"
if [ "$IP" = "tailscale" ]; then
  HOST="100.103.66.92"
else
  HOST="192.168.1.18"
fi

echo "Checking Dell server at $HOST..."
echo ""

ssh -o ConnectTimeout=5 pronav@$HOST "
echo '=== SYSTEM ==='
uptime
echo ''
echo '=== MEMORY ==='
free -h
echo ''
echo '=== DISK ==='
df -h /
echo ''
echo '=== DOCKER CONTAINERS ==='
sudo docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ''
echo '=== SERVICES ==='
for s in ssh docker fail2ban wpa_supplicant ufw tailscaled; do
  echo \"\$s: \$(sudo systemctl is-active \$s)\"
done
echo ''
echo '=== NETWORK ==='
ip -4 a | grep 'inet ' | grep -v '127.0.0.1'
echo ''
echo '=== TAILSCALE ==='
tailscale ip 2>/dev/null || echo 'Tailscale not running'
" 2>&1

if [ $? -ne 0 ]; then
  echo "FAILED: Cannot reach server at $HOST"
  echo "Try: $0 tailscale (if you're not on home network)"
fi
