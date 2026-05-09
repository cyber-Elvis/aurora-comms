#!/bin/bash
# Bootstrap Sentinel Ridge lab dependencies on Dell WSL Ubuntu.
# Idempotent — safe to re-run.
set -e

echo "=== Step 1: System update ==="
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

echo ""
echo "=== Step 2: Install Docker Engine (native, NOT Docker Desktop) ==="
if ! command -v docker >/dev/null; then
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  echo "[OK] Docker installed"
else
  echo "[OK] Docker already installed: $(docker --version)"
fi

echo ""
echo "=== Step 3: Add $USER to docker group ==="
sudo usermod -aG docker $USER || true

echo ""
echo "=== Step 4: Start Docker service ==="
sudo service docker start
sleep 3
sg docker -c "docker run --rm hello-world" | tail -5

echo ""
echo "=== Step 5: Install Containerlab ==="
if ! command -v containerlab >/dev/null; then
  bash -c "$(curl -sL https://get.containerlab.dev)"
else
  echo "[OK] Containerlab already installed: $(containerlab version | head -1)"
fi

echo ""
echo "=== Step 6: Install GitHub CLI ==="
if ! command -v gh >/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg 2>/dev/null
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update
  sudo apt install -y gh
else
  echo "[OK] gh already installed"
fi

echo ""
echo "=== Step 7: Configure git ==="
git config --global user.name "Elvis Ifeanyi Nwosu"
git config --global user.email "elvisifeanyi67@gmail.com"
git config --global init.defaultBranch main

echo ""
echo "=== Bootstrap complete ==="
echo ""
echo "Next steps:"
echo "  1. Close and reopen this Ubuntu terminal (so docker group sticks)"
echo "  2. cd ~/aurora-comms"
echo "  3. gh auth login            # web browser flow + HTTPS"
echo "  4. bash _setup/dell/deploy.sh"
