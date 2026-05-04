#!/bin/bash
# Deploy docker-compose to Dell server
# Usage: ./deploy-compose.sh [local|tailscale]

IP="${1:-local}"
if [ "$IP" = "tailscale" ]; then
  HOST="100.103.66.92"
else
  HOST="192.168.1.18"
fi

echo "Deploying docker-compose to $HOST..."

# Copy compose file to server
scp "$(dirname "$0")/../docker/docker-compose.yml" pronav@$HOST:~/docker/docker-compose.yml

# Deploy
ssh pronav@$HOST "cd ~/docker && sudo docker compose pull && sudo docker compose up -d"

echo "Done. Checking containers..."
ssh pronav@$HOST "sudo docker ps --format 'table {{.Names}}\t{{.Status}}'"
