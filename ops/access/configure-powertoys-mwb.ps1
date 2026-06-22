#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$SecurityKeyBase64,
    [Parameter(Mandatory = $true)][string]$NameMappingsBase64,
    [Parameter(Mandatory = $true)][string[]]$AllowedRemoteAddress,
    [string[]]$MachineMatrix = @("FORTY3S-PC2", "FORTY3S-PC1", "FORTY3S-PC3", ""),
    [switch]$InteractiveLaunch,
    [switch]$SkipFirewall
)

$ErrorActionPreference = "Stop"
$securityKey = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($SecurityKeyBase64)
)
$nameMappings = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($NameMappingsBase64)
)
$root = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys"
$mainPath = Join-Path $root "settings.json"
$mwbDirectory = Join-Path $root "MouseWithoutBorders"
$mwbPath = Join-Path $mwbDirectory "settings.json"
$powerToysExe = Join-Path $env:ProgramFiles "PowerToys\PowerToys.exe"
$mwbExe = Join-Path $env:ProgramFiles "PowerToys\PowerToys.MouseWithoutBorders.exe"

Get-Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Path -like "C:\Program Files (x86)\Microsoft Garage\Mouse without Borders\*"
    } |
    Stop-Process -Force -ErrorAction SilentlyContinue

$legacyService = Get-Service -Name "MouseWithoutBordersSvc" -ErrorAction SilentlyContinue
if ($legacyService) {
    Stop-Service -Name $legacyService.Name -Force -ErrorAction SilentlyContinue
    Set-Service -Name $legacyService.Name -StartupType Disabled
}

Get-Process `
    -Name "PowerToys", "PowerToys.MouseWithoutBorders", "PowerToys.MouseWithoutBordersHelper" `
    -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path $mwbDirectory -Force | Out-Null

if ((Test-Path -LiteralPath $mainPath) -and (Get-Item -LiteralPath $mainPath).Length -gt 0) {
    try {
        $mainSettings = Get-Content -LiteralPath $mainPath -Raw | ConvertFrom-Json
    } catch {
        Copy-Item -LiteralPath $mainPath -Destination "$mainPath.corrupt-$(Get-Date -Format yyyyMMddHHmmss)" -Force
        $mainSettings = $null
    }
}

if ($mainSettings) {
    $mainSettings.startup = -not $InteractiveLaunch
    if (-not $mainSettings.enabled) {
        $mainSettings | Add-Member NoteProperty enabled ([pscustomobject]@{})
    }
    if ($mainSettings.enabled.PSObject.Properties.Name -contains "MouseWithoutBorders") {
        $mainSettings.enabled.MouseWithoutBorders = $true
    } else {
        $mainSettings.enabled | Add-Member NoteProperty MouseWithoutBorders $true
    }
} else {
    $mainSettings = [ordered]@{
        startup = -not $InteractiveLaunch
        enabled = [ordered]@{ MouseWithoutBorders = $true }
        show_tray_icon = $true
        run_elevated = $false
        powertoys_version = "v0.100.0"
    }
}

$mainTemporaryPath = "$mainPath.tmp"
$mainSettings |
    ConvertTo-Json -Depth 20 -Compress |
    Set-Content -LiteralPath $mainTemporaryPath -Encoding utf8
Move-Item -LiteralPath $mainTemporaryPath -Destination $mainPath -Force

if ((Test-Path -LiteralPath $mwbPath) -and (Get-Item -LiteralPath $mwbPath).Length -gt 0) {
    try {
        $mwbSettings = Get-Content -LiteralPath $mwbPath -Raw | ConvertFrom-Json
    } catch {
        Copy-Item -LiteralPath $mwbPath -Destination "$mwbPath.corrupt-$(Get-Date -Format yyyyMMddHHmmss)" -Force
        $mwbSettings = $null
    }
}

if (-not $mwbSettings) {
    $mwbSettings = [pscustomobject]@{
        properties = [pscustomobject]@{
            SecurityKey = [pscustomobject]@{ value = "" }
            UseService = [pscustomobject]@{ value = $false }
            ShowOriginalUI = [pscustomobject]@{ value = $false }
            WrapMouse = [pscustomobject]@{ value = $true }
            ShareClipboard = [pscustomobject]@{ value = $true }
            TransferFile = [pscustomobject]@{ value = $true }
            HideMouseAtScreenEdge = [pscustomobject]@{ value = $true }
            DrawMouseCursor = [pscustomobject]@{ value = $true }
            ValidateRemoteMachineIP = [pscustomobject]@{ value = $false }
            SameSubnetOnly = [pscustomobject]@{ value = $false }
            BlockScreenSaverOnOtherMachines = [pscustomobject]@{ value = $true }
            MoveMouseRelatively = [pscustomobject]@{ value = $false }
            BlockMouseAtScreenCorners = [pscustomobject]@{ value = $false }
            ShowClipboardAndNetworkStatusMessages = [pscustomobject]@{ value = $false }
            MachineMatrixString = @()
            MachinePool = [pscustomobject]@{ value = ":,:,:,:" }
            MatrixOneRow = [pscustomobject]@{ value = $true }
            EasyMouse = [pscustomobject]@{ value = 1 }
            DisableEasyMouseWhenForegroundWindowIsFullscreen = [pscustomobject]@{ value = $true }
            EasyMouseFullscreenSwitchBlockExcludedApps = [pscustomobject]@{ value = @() }
            MachineID = [pscustomobject]@{ value = 0 }
            LastX = [pscustomobject]@{ value = 0 }
            LastY = [pscustomobject]@{ value = 0 }
            PackageID = [pscustomobject]@{ value = 0 }
            FirstRun = [pscustomobject]@{ value = $false }
            HotKeySwitchMachine = [pscustomobject]@{ value = 112 }
            TCPPort = [pscustomobject]@{ value = 15100 }
            DrawMouseEx = [pscustomobject]@{ value = $true }
            Name2IP = [pscustomobject]@{ value = "" }
            FirstCtrlShiftS = [pscustomobject]@{ value = $false }
            DeviceID = [pscustomobject]@{ value = "" }
        }
        name = "MouseWithoutBorders"
        version = "1.1"
    }
}

$mwbSettings.properties.SecurityKey.value = $securityKey
# Preserve UseService when this script is re-run. Service registration and the
# elevated transition are handled by enable-powertoys-mwb-service.ps1.
$mwbSettings.properties.MachineMatrixString = @($MachineMatrix)
$mwbSettings.properties.Name2IP.value = $nameMappings
$mwbSettings.properties.ShareClipboard.value = $true
$mwbSettings.properties.TransferFile.value = $true
$mwbSettings.properties.SameSubnetOnly.value = $false
$mwbSettings.properties.ValidateRemoteMachineIP.value = $false
$mwbSettings.properties.TCPPort.value = 15100
$mwbSettings.properties.FirstRun.value = $false

$mwbTemporaryPath = "$mwbPath.tmp"
$mwbSettings |
    ConvertTo-Json -Depth 30 -Compress |
    Set-Content -LiteralPath $mwbTemporaryPath -Encoding utf8
Move-Item -LiteralPath $mwbTemporaryPath -Destination $mwbPath -Force

if (-not $SkipFirewall) {
foreach ($protocol in "TCP", "UDP") {
    $ruleName = "Aurora-PowerToys-MWB-$protocol"
    try {
        Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue |
            Remove-NetFirewallRule
        New-NetFirewallRule `
            -Name $ruleName `
            -DisplayName "Aurora PowerToys MWB $protocol" `
            -Enabled True `
            -Direction Inbound `
            -Action Allow `
            -Profile Any `
            -Protocol $protocol `
            -LocalPort 15100-15101 `
            -RemoteAddress $AllowedRemoteAddress `
            -ErrorAction Stop | Out-Null
    } catch {
        $existingRule = Get-NetFirewallRule -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Enabled -eq "True" -and
                $_.Direction -eq "Inbound" -and
                $_.Action -eq "Allow" -and
                $_.DisplayName -match "MWB|Mouse without Borders"
            } |
            Select-Object -First 1
        if (-not $existingRule) {
            throw
        }
        Write-Warning "Keeping existing MWB firewall rule because the current token cannot refresh it."
    }
}
}

if ($InteractiveLaunch) {
    Remove-ItemProperty `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name "PowerToys" `
        -ErrorAction SilentlyContinue

    $taskName = "Aurora-Start-PowerToys-Interactive"
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $launchCommand = @"
`$powerToys = '$($powerToysExe -replace "'", "''")'
`$mwb = '$($mwbExe -replace "'", "''")'
if (-not (Get-Process PowerToys -ErrorAction SilentlyContinue)) {
    Start-Process `$powerToys
}
Start-Sleep -Seconds 10
if (-not (Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue)) {
    Start-Process `$mwb
}
"@
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($launchCommand)
    )
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -EncodedCommand $encodedCommand"
    $principal = New-ScheduledTaskPrincipal `
        -UserId $identity `
        -LogonType Interactive `
        -RunLevel Limited
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $identity
    $taskSettings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Principal $principal `
        -Trigger $trigger `
        -Settings $taskSettings `
        -Description "Start PowerToys and ensure Mouse Without Borders is running." `
        -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
} else {
    New-ItemProperty `
        -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
        -Name "PowerToys" `
        -Value "`"$powerToysExe`"" `
        -PropertyType String `
        -Force | Out-Null

    Start-Process -FilePath $powerToysExe
    Start-Sleep -Seconds 3
    Start-Process -FilePath $mwbExe
}

Start-Sleep -Seconds 8

[pscustomobject]@{
    Computer = $env:COMPUTERNAME
    PowerToys = (Get-Process PowerToys -ErrorAction SilentlyContinue | Measure-Object).Count
    MWB = (Get-Process PowerToys.MouseWithoutBorders -ErrorAction SilentlyContinue | Measure-Object).Count
    Port15100 = (
        Get-NetTCPConnection -State Listen -LocalPort 15100 -ErrorAction SilentlyContinue |
            Measure-Object
    ).Count
    Matrix = $MachineMatrix -join "|"
    Mappings = $nameMappings
}
