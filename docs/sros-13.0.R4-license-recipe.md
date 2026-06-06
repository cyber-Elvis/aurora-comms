# Nokia SR OS 13.0.R4 VSIM License Recipe in hellt/vrnetlab

Complete reproducible recipe for running licensed SR OS 13.0.R4 inside hellt/vrnetlab Docker containers, with the 2015-era VSIM license clock-frozen via the RTC trick.

This recipe is the result of a multi-day investigation that hit five distinct gotchas. It documents both the working pattern and the failure modes so anyone following can skip the dead ends.

## TL;DR — Final working setup

| Component | Required |
| --- | --- |
| TiMOS qcow2 | `TiMOS-SR-13.0.R4-vm.qcow2` (or any SR OS 13.x VSIM image) |
| License file content | UUID + **literal space** + JOINED BLOB on **one line**, then comment with date |
| vrnetlab base | hellt/vrnetlab master (`ghcr.io/srl-labs/vrnetlab-base:0.2.0`) |
| launch.py patches | Three patches (see §3) |
| qemu RTC | `-rtc base=2015-03-10` (or any date in license window) |
| TFTP daemon | Started manually after each container start (until persistent fix) |
| KVM | `--device /dev/kvm` required for reasonable boot times |

Verified result after applying everything:
```
A:vr-sros# show system license
License status : monitoring, valid license record
Time remaining : 175 days
License name   : ALCATEL-LUCENT 7750 SROS-vSIM
License uuid   : 00000000-0000-0000-0000-000000000000
License sros   : TiMOS-[BC]-13.0.*
```

## 1. License file format — THE critical detail

**License must be ONE line.** UUID + literal space + the full base64 BLOB joined with no internal whitespace.

```
00000000-0000-0000-0000-000000000000 lACwArxxPh3AACQAJAYKNk55QyofTkd6KUp0JHQ8LzweTnopOA9+YkVqNRcDAAUAAAAAAAUAHAAWbPlUAAAAAAAAAAAAAAAAf+rkVQAAAADAAEAAZCshaWUcUVdKETdefGQoJzJGBWo5enFSJhopaR5jaTcHPhEJeA8Icx0SE3McZntfGXUvDVEMGnhadEArAQApADAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMAAAAAAEABYAVGlNT1MtW0JDXS0xMy4wLioAAADAABwAUGs1GnxiS3QxCE0rRkwNMnxPYTJ7KGkQBgAMAAEAAQAAAAAAAgAiAEFMQ0FURUwtTFVDRU5UIDc3NTAgU1JPUy12U0lNAAAAwAAwACMQJjAIOHVXYXIhdl9UDylabEV7TgJKB1VCWHIkNVgYDz82QwkVPX4PInhiDwBdAWtQREttQVJLRThKWnhCdkIzNkIyQmIyMzRwd3VaZzc1K2NqMGZRZnNXa0JEQTFXK3Z1TVBaY0lSaUVNK0swQTBOb1FSTjRiQVZCREJBTUx4MS96S0pGckJkSVlmSEdOM0FKaWJPT0hIYm0wRUdvRzJyYXdSeHNuN1NRajdhQ0VjOFlJMlVoY1dTUEZIZDBUaTJIVnh6RXJxdVd6cHhaU3FaYWxGWGpPa2c1UlVqYnBuSzZiM0FKeWZVOG1qbW0ydSs2RGY5a1hDYytHQ0txZm0zVzZ0VXNFUjN3U2IvQk83WkdZa2ltMjBtbUhTUWhaNnBmaDJWMTJ6YjJseU1FdUJpeHJTMVB3ejA5d1FrYmZKZC9xWWwrdUxmUTEvK2lub1FDQktsMkZtSUU2ZFlDYjFvRGc1WVlNdlpQbzRmRndzSzZQVnRwdXM1MGpMMDdMMThrQjhyUT09AAAAAA==
# 2015-03-09 ALCATEL-LUCENT 7750 SROS-vSIM(TiMOS-[BC]-13.0.*)
```

**Note the comment line:** `# 2015-03-09` is consumed by vrnetlab's regex to set `fake_start_date` = `date + 1 day` = `2015-03-10`. This drives the qemu `-rtc base=` argument. Without this date string, vrnetlab's faketime doesn't activate.

**Why one line:** vrnetlab's `launch.py` calls `license.split(" ")[0]` to extract the UUID. With multi-line content, `split(" ")` (literal space, not whitespace) returns the entire content as one token, then qemu gets that giant blob as its `-uuid` argument and breaks the command line. The result is qemu accepting the first UUID and ignoring blob lines as garbage args, while SR OS receives an unparseable multi-line file via TFTP. Single-line UUID + space + joined-BLOB satisfies both vrnetlab and SR OS parsers.

The user's original GNS3 notes said "make a space then copy and paste the remaining txt" — literal space, not Enter. The visual line wrap in displayed notes was display-only, not file-level newlines. Taking the displayed wraps as actual newlines causes the multi-line trap.

## 2. RTC date trick

SR OS 13.0.R4 VSIM licenses are valid for a fixed window in 2015. Current real time (2026+) is well past expiry, so SR OS reports "missing license record" unless the system clock is rolled back.

vrnetlab uses qemu's `-rtc base=YYYY-MM-DD` to set the emulated hardware clock. vrnetlab's launch.py extracts the date from the license file content via regex `([0-9]{4}-[0-9]{2}-)([0-9]{2})` and sets `fake_start_date` to date+1.

| In license file | RTC applied | Why |
| --- | --- | --- |
| `# 2015-03-09` | `2015-03-10` | Matches the working GNS3 reference setup |
| License issue date | `FRI MAR 06 08:57:58 UTC 2015` | (informational) |
| License end date | `MON AUG 31 23:59:59 UTC 2015` | (informational) |
| Valid window | ~178 days | Time remaining shown on `show system license` |

## 3. Three launch.py patches required

Apply these to `/<vrnetlab>/nokia/sros/docker/launch.py` BEFORE running `make docker-image`. All three are non-invasive and idempotent.

### Patch 1 — Date detection from comment lines

vrnetlab's original `read_license()` strips comment lines (starting with `#`) before searching for the YYYY-MM-DD date. Since our date is intentionally in the comment (so SR OS ignores it but vrnetlab finds it), this breaks. Patch reads the full file content separately for date detection.

Find:
```python
m = re.search("([0-9]{4}-[0-9]{2}-)([0-9]{2})", license)
```

Replace with:
```python
# PATCH: read full file (including comment lines) for date detection
with open("/tftpboot/license.txt", "r") as full_f:
    full_content = full_f.read()
m = re.search("([0-9]{4}-[0-9]{2}-)([0-9]{2})", full_content)
```

### Patch 2 — BOF empty-list guard

When running standalone (not under containerlab), vrnetlab's `gen_bof_config()` returns an empty list. scrapli's `send_configs` then calls `commands[-1]` on the empty list and crashes with `IndexError`.

Find:
```python
res = self.sros_con.send_configs(self.gen_bof_config(), strip_prompt=False)
```

Replace with:
```python
# PATCH 2: guard against empty BOF config list (standalone non-containerlab run)
bof_cmds = self.gen_bof_config()
if bof_cmds:
    res = self.sros_con.send_configs(bof_cmds, strip_prompt=False)
else:
    self.logger.info("No BOF config to send - skipping send_configs")
    res = None
```

### Patch 3 — Idempotent processFiles (restart safety)

`processFiles()` moves the qcow2 from `/sros-vm-X.X.X.qcow2` to `/sros.qcow2` on first launch. On any subsequent `docker restart`, the source file is gone and the function crashes with `AttributeError: 'SROS' object has no attribute 'qcow_name'`. Without this patch, Docker's `--restart=unless-stopped` policy will trigger a crash loop.

Find the `processFiles` method definition and add this check at the start:
```python
def processFiles(self):
    """processFiles renames the qcow2 image to sros.qcow2 and the license file to license.txt"""
    # PATCH 3: idempotent processFiles - skip if already processed (e.g. docker restart)
    if os.path.exists("/sros.qcow2") or os.path.exists("/sros-disk.qcow2"):
        self.logger.info("processFiles: target qcow2 already exists, skipping (idempotent path - container restart)")
        return
    # ... original logic
```

## 4. TFTP daemon — manual start required (for now)

vrnetlab's base image installs `in.tftpd` but doesn't start it. SR OS fetches the license file via TFTP at boot, so without the daemon running it sees "Could not find license file" even though the file exists at `/tftpboot/license.txt`.

After each container start, run:
```bash
docker exec -d sros-boot-test bash -c "in.tftpd -L -a 172.31.255.29:69 -s /tftpboot 2>&1 >/var/log/tftpd.log"
```

Verify:
```bash
docker exec sros-boot-test pgrep -af in.tftpd
```

The IP `172.31.255.29` is the br-mgmt bridge gateway inside the container. SR OS in the guest VM has IP `172.31.255.30/30` and fetches from this internal address.

## 5. Build sequence

```bash
SROS_DIR=~/vrnetlab/nokia/sros

# Stage qcow2
cp /path/to/TiMOS-SR-13.0.R4-vm.qcow2 $SROS_DIR/sros-vm-13.0.R4.qcow2

# Stage license file (use exact single-line format from §1)
cat > $SROS_DIR/sros-vm-13.0.R4.qcow2.license <<'EOF'
00000000-0000-0000-0000-000000000000 lACwArxxPh3...AAAAAA==
# 2015-03-09 ALCATEL-LUCENT 7750 SROS-vSIM(TiMOS-[BC]-13.0.*)
EOF

# Apply the three patches to launch.py (see §3)
# (Use a Python in-place editor or manual edit)

# Build
cd $SROS_DIR
make docker-image
# Produces: vrnetlab/nokia_sros:13.0.R4
```

## 6. Run command

```bash
docker run -d --name sros-boot-test \
    --privileged \
    --device /dev/kvm \
    --restart unless-stopped \
    -p 22025:22 \
    -p 5000:5000 \
    vrnetlab/nokia_sros:13.0.R4

# Wait ~10 seconds for launch.py
# Then start TFTP daemon
docker exec -d sros-boot-test bash -c "in.tftpd -L -a 172.31.255.29:69 -s /tftpboot 2>&1 >/var/log/tftpd.log"

# Wait 5-8 min for SR OS to fully boot
# SSH port 22025 will start listening when ready
```

## 7. Access pattern

### SSH via Tailscale (recommended)

Termius/OpenSSH client connects to:
- Host: `<host's Tailscale IP>`
- Port: 22025
- Username: `admin` or `vrnetlab`
- Password: `admin` or `VR-netlab9`

**Modern OpenSSH 10.2+ refuses the 2015-era DH key exchange.** Use Termius (libssh-based, more lenient) OR use OpenSSH with legacy flags:
```bash
ssh -p 22025 \
    -oKexAlgorithms=+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1,diffie-hellman-group14-sha1 \
    -oHostKeyAlgorithms=+ssh-rsa \
    -oPubkeyAcceptedAlgorithms=+ssh-rsa \
    admin@<tailscale-ip>
```

### Telnet console (fallback)

vrnetlab exposes the qemu serial console on internal port 5000. With `-p 5000:5000` port mapping, telnet to host port 5000:

```bash
telnet <tailscale-ip> 5000
```

## 8. Failure modes catalogued

| Symptom | Root cause | Fix |
| --- | --- | --- |
| Container crash loop, `AttributeError: qcow_name` | Patch 3 missing | Apply Patch 3, rebuild |
| `IndexError: list index out of range` in launch.py | Patch 2 missing | Apply Patch 2, rebuild |
| Boot logs: `License file found... start date None` | Patch 1 missing | Apply Patch 1, rebuild |
| `show system license` shows `missing license record` despite valid file | License file has multi-line BLOB | Reformat as single line per §1 |
| `show system license` shows expired | RTC date wrong (current=real-time) | Verify `# 2015-03-09` in license file; restart container |
| SR OS boot log: `Could not find TiMOS license file at tftp://...` | TFTP daemon not started | `docker exec -d ... in.tftpd ...` per §4 |
| qemu cmd shows BLOB lines as separate args (in `ps -ef`) | License has multi-line BLOB | Reformat as single line per §1 |
| Cannot SSH from modern OpenSSH | DH key exchange too modern | Use Termius OR add legacy flags per §7 |
| Container stops after `/admin save` | `--restart=unless-stopped` re-launching | Normal — qemu may signal exit on certain SR OS reboot commands |

## 9. Verification checklist

After applying everything:

- [ ] `docker ps` shows container Up, no restart count growth
- [ ] `docker exec ... pgrep in.tftpd` shows the daemon running
- [ ] Boot logs show `License file found for UUID 00000000-... with start date 2015-03-10`
- [ ] Boot logs show `Time from clock is XXX MAR XX 2015 UTC` (not 2026)
- [ ] qemu cmd shows clean `-uuid 00000000-0000-0000-0000-000000000000` (no blob spillover)
- [ ] `ss -tlnp | grep ':22 '` inside container shows SSH listening
- [ ] From Termius: SSH succeeds, prompt is `A:vRR#` then `*A:vr-sros#` after bootstrap
- [ ] `show system license` shows `monitoring, valid license record, 175 days remaining`

## 10. Notes for future contributions

The split(" ") vs split() bug in launch.py is a candidate for an upstream PR to hellt/vrnetlab. Multi-line license files are a reasonable user expectation (it's how the format looks when displayed). A 4-character change from `split(" ")[0]` to `split()[0]` would make the parser robust to either format without breaking the single-line case.

---

Recipe captured Sunday 2026-06-07 from end-to-end working deployment on PC1 (FORTY3S-PC1) WSL Ubuntu, native Docker.

Tested SR OS 13.0.R4. Pattern should generalize to other SR OS 13.x versions with the same license. Untested with 14.x+ — newer images use different license validation and likely won't accept this 2015 blob even with the date trick.
