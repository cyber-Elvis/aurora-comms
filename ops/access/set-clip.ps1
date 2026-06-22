#Requires -Version 5.1
<#
  Set the INTERACTIVE user's clipboard from C:\ProgramData\Aurora\clip.txt.

  Windows clipboards are per-window-station: a command run over SSH lands in the
  service session's clipboard, not WinSta0\Default where the logged-on user pastes
  from. So this script is launched by the on-demand task `Aurora-SetClipboard`
  (Principal = console user, Interactive) via run-set-clip.vbs (wscript, hidden) so
  it runs in the user's session and sets the clipboard they actually see.

  MULTI-ITEM: if clip.txt contains the separator token (===AURORA-CLIP-SEP===), each
  chunk is set on the clipboard in turn with a short gap, so each becomes its own
  Win+V clipboard-history entry — paste them one at a time from clipboard history.
  Otherwise the whole file is set as a single clipboard item.

  Delivery flow (from PC1): stage text into clip.txt over SSH, then
  Start-ScheduledTask Aurora-SetClipboard.
#>
$ErrorActionPreference = 'SilentlyContinue'

# Ensure Win+V clipboard history is on for this user (idempotent).
$k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Clipboard'
if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
Set-ItemProperty -Path $k -Name 'EnableClipboardHistory' -Value 1 -Type DWord
Start-Sleep -Milliseconds 700

$f = Join-Path $env:ProgramData 'Aurora\clip.txt'
if (-not (Test-Path $f)) { return }
$raw = [IO.File]::ReadAllText($f)

# Split into items ONLY where the separator token sits on its own line, so a single item
# may safely *mention* the token inline (e.g. documentation / this delivery prompt itself).
$parts = [regex]::Split($raw, "\r?\n===AURORA-CLIP-SEP===\r?\n")
if ($parts.Count -gt 1) {
  foreach ($it in $parts) {
    $v = $it.Trim("`r", "`n")
    if ($v.Length -gt 0) {
      Set-Clipboard -Value $v
      Start-Sleep -Milliseconds 700   # gap so each lands as a distinct Win+V entry (and eases MWB clipboard-sync load)
    }
  }
} else {
  Set-Clipboard -Value $raw
}
