Clipboard delivery — push commands/config straight to the machine where I'll paste (PC1/PC2/PC3)

Why: I run Termius on PC3 and move between PC1/PC2/PC3. Instead of making me copy-paste
across machines (which fights Mouse Without Borders' rich-clipboard sync), put any
command/config you produce directly on the DESTINATION machine's clipboard, and tell me
which machine. For a set of separate snippets, push them as MULTIPLE clipboard-history
entries so I open Win+V and paste each in turn. Do this automatically; don't ask each time.

Infrastructure (already deployed + persistent on PC1, PC2, PC3; survives reboot):
- C:\ProgramData\Aurora\set-clip.ps1  — sets the clipboard from C:\ProgramData\Aurora\clip.txt.
  If clip.txt contains the separator token on its own line, it sets each chunk in turn
  (~700ms apart) so each becomes its own Win+V clipboard-history entry; also enables Win+V
  history. A single item may safely mention the token inline.
- C:\ProgramData\Aurora\run-set-clip.vbs  — hidden wscript launcher (no console flash).
- Scheduled task "Aurora-SetClipboard" — Interactive, runs as the console user, so it sets
  the clipboard I actually paste from (defeats Windows session isolation).
- SSH aliases: pc2 (forty3@192.168.137.1), pc3 (elvis@100.110.254.10). PC1 is local.
- MWB "Share clipboard" is ON, so text may also mirror to the other machines — harmless.
- Repo source (redeploy if ever missing): ops/access/set-clip.ps1, ops/access/run-set-clip.vbs.

Destination convention:
- Node config / anything I paste in Termius  -> PC3 (default)
- PC2-specific command                       -> PC2
- PC1-specific command                       -> PC1
Always tell me which machine + how many items, e.g.:
"On PC3's clipboard (3 items) — Win+V and paste each in Termius."

How to push (PowerShell) — one function, single OR multiple snippets, any machine. The
separator is a line containing only the token, so items are joined with newline+token+newline:

function Push-Clip {
  param(
    [Parameter(Mandatory)][ValidateSet('pc1','pc2','pc3')][string]$Dest,
    [Parameter(Mandatory)][string[]]$Items
  )
  $sep = "`n" + '===AURORA-CLIP-SEP===' + "`n"
  $joined = ($Items -join $sep)
  $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($joined))
  $stage = @'
$d=[Convert]::FromBase64String("__B64__"); $t=[Text.Encoding]::UTF8.GetString($d)
[IO.File]::WriteAllText("$env:ProgramData\Aurora\clip.txt",$t,(New-Object Text.UTF8Encoding($false)))
Start-ScheduledTask -TaskName "Aurora-SetClipboard"
'@ -replace '__B64__', $b64
  if ($Dest -eq 'pc1') { Invoke-Expression $stage }
  else {
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($stage))
    ssh $Dest powershell -NoProfile -EncodedCommand $enc | Out-Null
  }
  "Pushed $($Items.Count) item(s) to $Dest"
}

# Single snippet:  Push-Clip pc3 'show running-config'
# Multiple (each = its own Win+V entry):
#                  Push-Clip pc3 @('configure','router isis CORE','commit')

Notes:
- Only push actual pasteable text. Keystroke instructions (e.g. "Ctrl+B then D") stay as
  written steps, not clipboard items.
- Termius paste is rebound to Ctrl+V; in terminals also Ctrl+Shift+V. Bracketed paste at the
  bash prompt is stripped via ~/.inputrc; for IOS-XR router consoles, inject config directly
  (iolcfg / tmux send-keys) rather than pasting, to avoid bracketed-paste markers.
- If "Aurora-SetClipboard" is missing on a machine, redeploy the two files to
  C:\ProgramData\Aurora\ and re-register the task (Interactive principal, console user).
