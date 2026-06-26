#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('pc1', 'pc2', 'pc3')]
    [string]$Dest,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Items
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$separator = "`n===AURORA-CLIP-SEP===`n"
$joined = $Items -join $separator
$contentBase64 = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes($joined)
)

$stage = @'
$ProgressPreference = 'SilentlyContinue'
$d = [Convert]::FromBase64String("__CONTENT_BASE64__")
$t = [Text.Encoding]::UTF8.GetString($d)
$path = Join-Path $env:ProgramData 'Aurora\clip.txt'
[IO.File]::WriteAllText($path, $t, (New-Object Text.UTF8Encoding($false)))
Start-ScheduledTask -TaskName 'Aurora-SetClipboard'
'@.Replace('__CONTENT_BASE64__', $contentBase64)

if ($Dest -eq 'pc1') {
    Invoke-Expression $stage
} else {
    $encodedStage = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($stage)
    )
    & ssh.exe $Dest powershell.exe -NoProfile -EncodedCommand $encodedStage 2>&1 |
        Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Clipboard delivery to $Dest failed with SSH exit code $LASTEXITCODE."
    }
}

"Pushed $($Items.Count) item(s) to $Dest"
