#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$SkipInteractiveRestart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$serviceName = "PowerToys.MWB.Service"
$powerToysDirectory = Join-Path $env:ProgramFiles "PowerToys"
$serviceExe = Join-Path $powerToysDirectory "PowerToys.MouseWithoutBordersService.exe"
$mwbExe = Join-Path $powerToysDirectory "PowerToys.MouseWithoutBorders.exe"
$settingsDirectory = Join-Path $env:LOCALAPPDATA "Microsoft\PowerToys\MouseWithoutBorders"
$settingsPath = Join-Path $settingsDirectory "settings.json"
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$userName = $identity.Name
$userSid = $identity.User.Value

foreach ($requiredPath in @($serviceExe, $mwbExe, $settingsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Required PowerToys MWB path not found: $requiredPath"
    }
}

$serviceBinaryPath = '"' + $serviceExe + '" ' + ($env:LOCALAPPDATA -replace '"', '\"')
$existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

if (-not $existingService) {
    New-Service `
        -Name $serviceName `
        -BinaryPathName $serviceBinaryPath `
        -DisplayName $serviceName `
        -StartupType Manual | Out-Null
} else {
    & sc.exe config $serviceName `
        binPath= $serviceBinaryPath `
        start= demand `
        obj= LocalSystem | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to refresh the $serviceName service definition."
    }
}

# Match the PowerToys v0.100.0 service ACL. The logged-in user may start and
# stop the demand-start LocalSystem helper without running PowerToys elevated.
$serviceSddl = (
    "D:" +
    "(A;;CCLCSWRPWPDTLOCRRC;;;SY)" +
    "(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)" +
    "(A;;CCLCSWLOCRRC;;;IU)" +
    "(A;;CCLCSWLOCRRC;;;SU)" +
    "(A;;CR;;;AU)" +
    "(A;;CCLCSWRPWPDTLOCRRC;;;PU)" +
    "(A;;RPWPDTLO;;;$userSid)" +
    "S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"
)
& sc.exe sdset $serviceName $serviceSddl | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to apply the PowerToys MWB service security descriptor."
}

$settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
if (-not $settings.properties -or -not $settings.properties.UseService) {
    throw "PowerToys MWB settings do not contain properties.UseService."
}

$backupPath = "$settingsPath.pre-service-$(Get-Date -Format yyyyMMdd-HHmmss).bak"
Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force
$settings.properties.UseService.value = $true

$temporaryPath = "$settingsPath.tmp"
$settings |
    ConvertTo-Json -Depth 30 -Compress |
    Set-Content -LiteralPath $temporaryPath -Encoding utf8
Move-Item -LiteralPath $temporaryPath -Destination $settingsPath -Force

if (-not $SkipInteractiveRestart) {
    Get-Process `
        -Name "PowerToys.MouseWithoutBorders", "PowerToys.MouseWithoutBordersHelper" `
        -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    # The demand-start service launches separate SYSTEM-owned MWB processes on
    # the normal and Winlogon desktops, then returns to Stopped by design.
    Start-Service -Name $serviceName
    Start-Sleep -Seconds 12
}

$service = Get-CimInstance Win32_Service -Filter "Name='$serviceName'"
$settingsCheck = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
$mwbProcesses = Get-CimInstance Win32_Process -Filter "Name='PowerToys.MouseWithoutBorders.exe'" -ErrorAction SilentlyContinue
$processOwners = foreach ($process in $mwbProcesses) {
    $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner -ErrorAction SilentlyContinue
    if ($owner -and $owner.ReturnValue -eq 0) {
        "$($owner.Domain)\$($owner.User)"
    }
}

[pscustomobject]@{
    Computer = $env:COMPUTERNAME
    User = $userName
    PowerToysVersion = (Get-Item (Join-Path $powerToysDirectory "PowerToys.exe")).VersionInfo.ProductVersion
    UseService = [bool]$settingsCheck.properties.UseService.value
    ServiceName = $service.Name
    ServiceStartMode = $service.StartMode
    ServiceState = $service.State
    ServicePath = $service.PathName
    MWBProcessCount = @($mwbProcesses).Count
    MWBProcessOwners = (@($processOwners | Sort-Object -Unique) -join ", ")
    SettingsBackup = $backupPath
}
