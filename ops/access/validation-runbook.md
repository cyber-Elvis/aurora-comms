# Aurora access validation runbook

Use this runbook after provisioning `aurora-codex` / `aurora-claude`, after changing Tailscale ACLs, and before adding a new cloud site.

## 1. Inventory and command rendering

```powershell
.\ops\access\aurora-ssh.ps1 -List
.\ops\access\aurora-ssh.ps1 mel-p1 -PrintOnly
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex -PrintOnly
.\ops\access\aurora-ssh.ps1 sros-legacy-lab -Profile sros-legacy -PrintOnly
```

Pass criteria:

- No command contains a password, private key text, `secret 9`, API token, or cloud credential.
- `sros-legacy` options appear only for aliases explicitly using `profile: sros-legacy`.
- `-UseCodex` / `-UseClaude` is refused for host-scope aliases such as `pc2-gns3`.

## 2. Positive access tests

From PC1 or another approved operator host:

```powershell
.\ops\access\aurora-ssh.ps1 mel-p1 -UseCodex
.\ops\access\aurora-ssh.ps1 mel-p1 -UseClaude
```

On the device, confirm:

```text
show users
show privilege
show logging | include SSH|LOGIN|CONFIG
```

Pass criteria:

- `aurora-codex` and `aurora-claude` can authenticate to selected lab nodes.
- Login events are visible in device logs and forwarded to the logging/SIEM path once enabled.
- The user's `admin` account still works as break-glass access.

## 3. Identity boundary checks

Confirm the automation accounts exist only on lab nodes.

Pass criteria:

- `aurora-codex` and `aurora-claude` do not exist on PC1 Windows, PC1 WSL, PC2 Windows, the GNS3 VM host OS, DO host OS, Oracle host OS, GitHub, or personal endpoints.
- Private keys remain only on PC1 or another approved operator host.
- No private key is copied into GNS3 projects, router flash, cloud images, containerlab bind mounts, or this repo.

## 4. Node-to-host deny tests

From a lab node that has a shell or test client, attempt to reach host admin services. Use platform-appropriate commands.

Targets:

| Host | Services that must be denied |
| --- | --- |
| PC1 `192.168.200.1` | SSH 22, RPC 135, NetBIOS 139, SMB 445, RDP 3389, WinRM 5985/5986, hypervisor/admin ports |
| PC2/Dell `192.168.200.2` | SSH 22/2222, RPC 135, NetBIOS 139, SMB 445, RDP 3389, WinRM 5985/5986, GNS3 host/admin ports such as 3080 unless explicitly approved for the test |
| DO host | SSH 22 and host admin ports from lab-node tags |
| Oracle host | SSH 22 and host admin ports from lab-node tags |

Local GNS3 guard:

```bash
# On the GNS3 VM, before testing from lab nodes.
sudo sh ./ops/access/host-guard/gns3-vm-host-guard.sh apply
sudo sh ./ops/access/host-guard/gns3-vm-host-guard.sh status
```

IOS/IOL test shape:

```ios
terminal length 0
telnet 192.168.200.1 22
telnet 192.168.200.1 445
telnet 192.168.200.1 3389
telnet 192.168.200.1 5985
telnet 192.168.200.1 5986
telnet 192.168.200.2 22
telnet 192.168.200.2 2222
telnet 192.168.200.2 3080
telnet 192.168.200.2 445
telnet 192.168.200.2 3389
telnet 192.168.200.2 5985
telnet 192.168.200.2 5986
telnet 192.168.200.1 3323
```

Pass criteria:

- Lab nodes cannot initiate admin sessions to host OSes.
- The explicit RPKI exception to PC1 `192.168.200.1:3323` works only where required.
- Denied attempts increment the GNS3 guard, site-demarcation ACL, host firewall, or equivalent deny counter.
- Denied attempts are visible in Wazuh/SIEM as `Aurora: lab node attempted a protected host service`.

## 5. Tailscale ACL checks

Expected model:

- `tag:hosts` can initiate to `tag:lab` for approved management ports.
- `tag:lab` cannot initiate to `tag:hosts`.
- Cloud host-to-host management is allowed only between approved host tags.

Pass criteria:

- A host can SSH to a lab node.
- A lab-tagged endpoint cannot SSH to PC1/PC2/DO/Oracle host tags.
- A lab-tagged endpoint can reach only the explicit `tag:rpki-rtr:3323` exception on the RPKI host.
- No broad `*:*` rule bypasses the host-isolation model.
- The `tests` block in `tailscale-acl.example.hujson` passes before the policy is applied.

Note: Tailscale ACLs do not govern ordinary local-LAN traffic from a lab node
to `192.168.200.0/24`; keep the GNS3 guard, site firewall, and host firewall
controls in place for the local Ethernet path.

## 6. Wazuh denied-flow checks

Install and test the local rule file:

```text
ops/access/wazuh/aurora-host-containment-rules.xml
```

Pass criteria:

- A denied GNS3 guard log with prefix `AURORA_HOST_GUARD denied` matches rule `100103`.
- A normalized JSON denied-flow event matches rule `100101`.
- A normalized JSON RPKI allow event to `192.168.200.1:3323` matches rule `100102` at low severity.
- No alert fires for ordinary host-to-lab management traffic.

## 7. Data-plane ring reconvergence

When the PC1-PC2-DO-Oracle lab edge ring is built:

1. Confirm all four edge adjacencies are up.
2. Confirm routes are present over the preferred path.
3. Disable one WireGuard/ring link.
4. Confirm eBGP/IS-IS reconverges over the remaining path.
5. Restore the link and confirm the expected best path returns.

Pass criteria:

- One ring-link failure does not partition the lab edge ring.
- Reconvergence does not create reachability from lab nodes into host OS management services.

## 8. Repo secret scan

Before each commit involving access tooling:

```powershell
git diff --cached
rg -n "BEGIN .*PRIVATE KEY|PRIVATE KEY|secret 9|password|api[_-]?key|token|client_secret" .
```

Pass criteria:

- Only placeholder text is present.
- No real private key, password, `secret 9`, API token, or cloud credential is staged.
