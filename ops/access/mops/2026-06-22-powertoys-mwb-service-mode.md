# MOP: PowerToys Mouse Without Borders service mode

## Objective

Allow the `PC2 | PC1 | PC3` Mouse Without Borders matrix to remain usable when
a remote PC is on the Windows lock screen or secure desktop.

## Root cause

PowerToys 0.100.0 had `UseService=false` on all three PCs. In that mode MWB
runs only in the logged-in user desktop and cannot inject input into the
Winlogon secure desktop. Clicking after crossing to a locked PC therefore
looked like a broken MWB connection.

PowerToys service mode runs separate MWB helpers as LocalSystem on the
`default` and `winlogon` desktops.

## Security decision

Enabling service mode deliberately permits authenticated members of the MWB
mesh to control the Windows lock screen and elevated applications.

Controls retained:

- MWB firewall scope remains restricted to the approved PC1/PC2/PC3 paths.
- The existing MWB security key and device matrix are unchanged.
- No Windows host-management credential is added to another PC.
- The service is demand-start, matching PowerToys, not always running.
- The service DACL grants start/stop rights only to the local interactive user
  plus standard Windows service principals.

## Implementation

Authoritative script:

```text
ops/access/enable-powertoys-mwb-service.ps1
```

The script:

1. registers `PowerToys.MWB.Service` as a LocalSystem demand-start service;
2. passes the current user's LocalAppData path to the service;
3. applies the PowerToys v0.100.0 service DACL;
4. backs up `MouseWithoutBorders/settings.json`;
5. atomically sets `UseService=true`;
6. starts the service so it creates the `default` and `winlogon` helpers.

## Applied state

Applied on 2026-06-22:

| PC | User profile | Result |
| --- | --- | --- |
| `FORTY3S-PC1` | `C:\Users\Elvis` | `UseService=true`; two MWB helpers; TCP 15100/15101 listening |
| `FORTY3S-PC2` | `C:\Users\Elvis-PC` (`forty3`) | `UseService=true`; two SYSTEM MWB helpers; TCP 15100 listening |
| `FORTY3S-PC3` | `C:\Users\Elvis` | `UseService=true`; two SYSTEM MWB helpers; TCP 15100 listening |

PC1 established paths after the change:

```text
PC1 192.168.137.81 <-> PC2 192.168.137.1
PC1 192.168.18.20  <-> PC3 192.168.18.29
```

PC2 uses its existing interactive PowerToys startup task. PC1 and PC3 have
PowerToys startup enabled in their main settings.

The service normally shows `Stopped` after activation. This is expected: it
starts the desktop helpers and exits.

## Validation

On each PC:

```powershell
$mwb = Get-Content -Raw `
  "$env:LOCALAPPDATA\Microsoft\PowerToys\MouseWithoutBorders\settings.json" |
  ConvertFrom-Json
$mwb.properties.UseService.value

sc.exe qc PowerToys.MWB.Service
netstat.exe -ano | findstr ":15100 :15101"
```

Functional test:

1. Leave PC1 unlocked.
2. Lock PC2 with `Win+L`.
3. Move from PC1 to PC2 and unlock PC2 through MWB.
4. Repeat with PC3.
5. Confirm PC2 and PC3 return to their normal desktops without the cursor
   dropping after the first click.

## Rollback

Run elevated on the affected PC:

```powershell
$path = "$env:LOCALAPPDATA\Microsoft\PowerToys\MouseWithoutBorders\settings.json"
$settings = Get-Content -Raw $path | ConvertFrom-Json
$settings.properties.UseService.value = $false
$settings | ConvertTo-Json -Depth 30 -Compress | Set-Content $path -Encoding utf8

Stop-Service PowerToys.MWB.Service -ErrorAction SilentlyContinue
sc.exe delete PowerToys.MWB.Service
Stop-Process -Name PowerToys.MouseWithoutBorders -Force -ErrorAction SilentlyContinue
Start-Process "C:\Program Files\PowerToys\PowerToys.MouseWithoutBorders.exe"
```

