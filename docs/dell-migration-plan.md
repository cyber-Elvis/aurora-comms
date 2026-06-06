# Region A Migration Plan — PC1 → Dell PC

Step-by-step migration plan to host Aurora Region A on Dell PC per ADR-002 v1.1 §3.1. Target session: next focused 3-hour block, fresh head.

## Pre-migration state

PC1 hosts everything (per `aurora-deployment-status.md`). Dell hosts only GNS3 SR OS. ADR-002 v1.1 designates Dell as Region A host. We migrate to close the drift.

## Phase 0 — Decision capture (5 min)

Confirm before starting:
- [ ] PC1 vrnetlab containers keep running as failover during migration
- [ ] Wazuh + MISP stay on PC1
- [ ] Cowork stays on PC1
- [ ] Dell will run all 7 vrnetlab vendor stacks
- [ ] Dell will run openconnect VPN endpoint for DevNet bridge
- [ ] Approximately 15 GB disk space available on Dell

## Phase 1 — Dell baseline prep (45 min)

### 1.1 Inventory current Dell state

Run on Dell WSL Ubuntu:
```bash
cat /etc/os-release | grep PRETTY_NAME
df -h /
free -h
for t in docker tailscale qemu-img tar unzip make git python3; do command -v $t >/dev/null && echo "OK $t" || echo "MISSING $t"; done
docker info >/dev/null 2>&1 && echo "docker daemon OK" || echo "docker daemon NOT RUNNING"
ps -p 1 -o comm=
uname -r
ls -la /dev/kvm 2>&1
sudo tailscale status 2>&1 | head -3
```

### 1.2 Install missing prerequisites

If Docker is missing:
```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# log out and back in to pick up group
```

If systemd is not PID 1, edit `/etc/wsl.conf`:
```
[boot]
systemd=true

[user]
default=fourty3
```
Then from Windows PowerShell: `wsl --shutdown`, reopen WSL.

If Tailscale is missing:
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
# follow the auth URL to add Dell to your Tailnet
```

Install other tools:
```bash
sudo apt update
sudo apt install -y qemu-utils tar unzip make build-essential git python3-pip
```

### 1.3 Verify KVM accessibility

```bash
ls -la /dev/kvm
sudo docker run --rm --device /dev/kvm alpine ls -la /dev/kvm
```

Both should show the device. If not, Hyper-V nested virt may not be enabled. Add to `%USERPROFILE%/.wslconfig` on Dell-Windows side:
```
[wsl2]
nestedVirtualization=true
```
Then `wsl --shutdown` from PowerShell, reopen.

### 1.4 Confirm Dell's Tailscale IP

```bash
sudo tailscale ip -4
```
Record this IP. It will be the new "Aurora Region A" endpoint replacing `100.116.32.29`.

## Phase 2 — Image transfer PC1 → Dell (30-45 min)

### 2.1 Save images on PC1 (~5-10 min)

```bash
mkdir -p ~/aurora-image-transfer && cd ~/aurora-image-transfer

# Save each image (each save takes 1-3 min)
docker save vrnetlab/vr-fortios:7.0.14 | gzip > vr-fortios.tar.gz
docker save vrnetlab/paloalto_pa-vm:9.0.4 | gzip > paloalto_pa-vm.tar.gz
docker save vrnetlab/nokia_sros:13.0.R4 | gzip > nokia_sros.tar.gz
docker save vrnetlab/cisco_csr1000v:16.08.01 | gzip > cisco_csr1000v.tar.gz
docker save vrnetlab/cisco_vios:L2-15.2 | gzip > cisco_vios.tar.gz
docker save ghcr.io/nokia/srlinux:24.10.1 | gzip > nokia_srlinux.tar.gz

ls -lah
# Expect ~8-10 GB total
```

### 2.2 Copy to Dell over Tailscale (~15-30 min depending on speed)

From PC1, copy via scp using Dell's Tailscale IP:
```bash
DELL_IP=<dell-tailscale-ip>
scp -r ~/aurora-image-transfer/ fourty3@$DELL_IP:~/
```

### 2.3 Load images on Dell (~5-10 min)

On Dell:
```bash
cd ~/aurora-image-transfer
for f in *.tar.gz; do
    echo "Loading $f ..."
    gunzip -c "$f" | docker load
done

docker images | grep -iE "vrnetlab|srlinux"
# Should show all 6 images
```

## Phase 3 — vrnetlab clone + license recipe on Dell (15 min)

### 3.1 Clone vrnetlab

```bash
cd ~
git clone https://github.com/hellt/vrnetlab.git
```

### 3.2 Apply three launch.py patches

The patched `launch.py` is in PC1's `/home/fourty3/vrnetlab/nokia/sros/docker/launch.py`. Copy it to Dell:

```bash
# On PC1
scp /home/fourty3/vrnetlab/nokia/sros/docker/launch.py fourty3@$DELL_IP:~/vrnetlab/nokia/sros/docker/launch.py

# Or use Cowork outputs - the patch documentation is in sros-13.0.R4-license-recipe.md §3
```

### 3.3 Stage license file

```bash
# Copy from PC1
scp /home/fourty3/vrnetlab/nokia/sros/sros-vm-13.0.R4.qcow2.license fourty3@$DELL_IP:~/vrnetlab/nokia/sros/

# Or recreate following sros-13.0.R4-license-recipe.md §1
```

### 3.4 Verify both files present

On Dell:
```bash
ls -la ~/vrnetlab/nokia/sros/sros-vm-13.0.R4.qcow2.license
grep -c "PATCH" ~/vrnetlab/nokia/sros/docker/launch.py
# Should be 3 occurrences (3 patches)
```

## Phase 4 — Start SR OS container on Dell + verify license (20 min)

The image is already loaded; we just need to start a container.

### 4.1 Start container with KVM passthrough

```bash
docker run -d --name sros-boot-test \
    --privileged \
    --device /dev/kvm \
    --restart unless-stopped \
    -p 22025:22 \
    -p 5000:5000 \
    vrnetlab/nokia_sros:13.0.R4
```

### 4.2 Start TFTP daemon manually

```bash
sleep 30
docker exec -d sros-boot-test bash -c "in.tftpd -L -a 172.31.255.29:69 -s /tftpboot 2>&1 >/var/log/tftpd.log"
docker exec sros-boot-test pgrep -af in.tftpd
```

### 4.3 Wait for SR OS SSH to come up (~6-8 min)

```bash
for i in $(seq 1 48); do
    sleep 10
    docker exec sros-boot-test bash -c "ss -tlnp 2>/dev/null | grep -q ':22 '" && echo "READY" && break
    echo "  ${i}0s booting..."
done
```

### 4.4 Verify license via Termius

Add Termius host:
- Address: Dell's Tailscale IP
- Port: 22025
- Type: SSH
- Username: admin, password: admin

```
A:vRR# show system license
```

Should see `monitoring, valid license record, 175 days remaining`.

## Phase 5 — Persistence chain on Dell (30 min)

### 5.1 Set restart policies for all containers

```bash
for c in $(docker ps -a --format '{{.Names}}' | grep -E 'sros|fortios|pa-|csr|vios|srlinux'); do
    docker update --restart=unless-stopped $c
done
```

### 5.2 Windows Task Scheduler — Dell side

From elevated PowerShell on Dell-Windows:
```powershell
schtasks /create /tn "AuroraWSL Startup" /tr "wsl.exe -d Ubuntu -- true" /sc onlogon /rl highest /f
```

### 5.3 Verify systemd services enabled

```bash
sudo systemctl is-enabled tailscaled docker
# Both should report "enabled"
```

### 5.4 Reboot test (optional but recommended)

```bash
# From PowerShell
wsl --shutdown
```

Wait, then reopen WSL terminal. Verify:
- Tailscale automatically back online
- Docker daemon up
- SR OS container starts and reaches license-valid state after ~6 min

## Phase 6 — Termius access via Dell Tailscale IP (15 min)

### 6.1 Add Dell host entries to Termius

Create a new Termius group "Aurora Dell Region A":
- SR OS PE-1: SSH to `<dell-tailscale-ip>:22025`
- (Same for any other ports as you bring up more containers)

### 6.2 Verify access from multiple Tailnet devices

- From phone via Tailscale → SSH to Dell IP works
- From PC1 → SSH to Dell IP works
- From another laptop → SSH to Dell IP works

### 6.3 Document in runbook

Update `aurora-deployment-status.md` to record Dell as Region A host.

## Phase 7 — ADR-002 v1.2 update + task accounting (30 min)

### 7.1 Update ADR-002 to v1.2

Add a revision history entry noting:
- Confirmed Region A on Dell per ADR-002 v1.1 §3.1
- Migration completed (date)
- PC1 retained as Wazuh + MISP + Cowork host (per §3.1)
- Dell as openconnect VPN bridge to DevNet CML (per §6) — pending VPN config

### 7.2 Optionally: stop PC1 vrnetlab containers

Only after Dell verified working for ≥1 day. Keep them in stopped state for fast revert if needed:
```bash
# On PC1
docker stop sros-boot-test
# (do not remove)
```

### 7.3 Update task tracking

Close `#61` (migration), update `#34` (Tailscale on Dell completed during Phase 1).

### 7.4 Commit

Push aurora-docs/ updates to `cyber-Elvis/aurora-comms` repo.

## Risk register

| Risk | Mitigation |
| --- | --- |
| KVM not available on Dell WSL | Hyper-V nested virt enable in .wslconfig + WSL shutdown |
| Image transfer interrupted | Resume scp + re-run docker load |
| Patched launch.py copy fails | Recreate from `sros-13.0.R4-license-recipe.md §3` |
| TFTP daemon doesn't start | Manual command per `sros-13.0.R4-license-recipe.md §4` |
| Dell systemd config drift | Phase 1.2 covers this; verify with `ps -p 1 -o comm=` |
| Tailscale auth flow blocked | Have user be at Dell physical screen for browser auth |

## Time budget

| Phase | Optimistic | Realistic |
| --- | --- | --- |
| 0 Decisions | 5 min | 5 min |
| 1 Dell prep | 30 min | 60 min |
| 2 Image transfer | 30 min | 60 min |
| 3 vrnetlab + license | 10 min | 20 min |
| 4 Start + verify | 15 min | 30 min |
| 5 Persistence | 20 min | 40 min |
| 6 Termius access | 10 min | 20 min |
| 7 ADR + commit | 20 min | 40 min |
| **Total** | **2 hours 20 min** | **4 hours 35 min** |

Plan for 4 hours. Start when fresh.
