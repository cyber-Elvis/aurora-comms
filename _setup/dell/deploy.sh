#!/bin/bash
# Deploy Aurora carrier backbone on the Dell.
# Assumes bootstrap.sh has run and you've reopened the terminal.
set -e

if ! docker ps >/dev/null 2>&1; then
  echo "ERROR: docker not accessible. Did you reopen the terminal after bootstrap?"
  echo "Try: newgrp docker; then re-run this script."
  exit 1
fi

REPO=$(git rev-parse --show-toplevel)
cd "$REPO/lab/backbone"

if [ ! -f topology.clab.yml ]; then
  echo "ERROR: topology.clab.yml not in $(pwd) — was the repo cloned correctly?"
  exit 1
fi

echo "=== Best-effort MPLS kernel enable ==="
sudo modprobe mpls_router 2>&1 || echo "(mpls_router unavailable; IS-IS+BGP will work, LDP may not)"
sudo modprobe mpls_iptunnel 2>&1 || true
sudo sysctl -w net.mpls.platform_labels=1024 2>/dev/null || true

echo ""
echo "=== Pulling FRR image ==="
docker pull frrouting/frr:latest

echo ""
echo "=== Deploying Aurora topology ==="
sudo containerlab deploy -t topology.clab.yml

echo ""
echo "=== Waiting 45s for protocols to converge ==="
sleep 45

echo ""
echo "=== IS-IS adjacencies on melbourne ==="
sudo docker exec clab-aurora-melbourne vtysh -c "show isis neighbor"

echo ""
echo "=== BGP summary on melbourne ==="
sudo docker exec clab-aurora-melbourne vtysh -c "show ip bgp summary"

echo ""
echo "=== Lab status ==="
sudo containerlab inspect -t topology.clab.yml
