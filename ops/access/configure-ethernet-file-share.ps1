#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$LocalAddressPattern = "192.168.137.*",
    [string]$RemoteSubnet = "192.168.137.0/24",
    [string]$ShareName = "AuroraShare",
    [string]$SharePath = "C:\AuroraShare",
    [string]$ShareUser = "AuroraShareSvc",
    [Parameter(Mandatory = $true)][string]$SharePasswordBase64,
    [Parameter(Mandatory = $true)][string]$PeerAddress,
    [Parameter(Mandatory = $true)][string]$PeerLabel,
    [Parameter(Mandatory = $true)][string]$PeerComputerName
)

$ErrorActionPreference = "Stop"
$plainPassword = [Text.Encoding]::UTF8.GetString(
    [Convert]::FromBase64String($SharePasswordBase64)
)
$securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

$interface = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object IPAddress -Like $LocalAddressPattern |
    Select-Object -First 1

if (-not $interface) {
    throw "No IPv4 interface matches $LocalAddressPattern."
}

Set-NetConnectionProfile `
    -InterfaceIndex $interface.InterfaceIndex `
    -NetworkCategory Private `
    -ErrorAction SilentlyContinue

Set-Service -Name LanmanServer -StartupType Automatic
Start-Service -Name LanmanServer

New-Item -ItemType Directory -Path $SharePath -Force | Out-Null

$localUser = Get-LocalUser -Name $ShareUser -ErrorAction SilentlyContinue
if ($localUser) {
    Set-LocalUser `
        -Name $ShareUser `
        -Password $securePassword `
        -PasswordNeverExpires $true `
        -UserMayChangePassword $false
} else {
    $localUser = New-LocalUser `
        -Name $ShareUser `
        -Password $securePassword `
        -Description "Aurora encrypted Ethernet file sharing" `
        -AccountNeverExpires `
        -PasswordNeverExpires `
        -UserMayNotChangePassword
}
Enable-LocalUser -Name $ShareUser
$shareUserSid = (Get-LocalUser -Name $ShareUser).Sid.Value

& icacls.exe $SharePath `
    /inheritance:r `
    /grant "*S-1-5-18:(OI)(CI)F" `
    /grant "*S-1-5-32-544:(OI)(CI)F" `
    /grant "*${shareUserSid}:(OI)(CI)M" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure NTFS permissions for $SharePath."
}

$existingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if ($existingShare -and $existingShare.Path -ne $SharePath) {
    Remove-SmbShare -Name $ShareName -Force
    $existingShare = $null
}

if (-not $existingShare) {
    New-SmbShare `
        -Name $ShareName `
        -Path $SharePath `
        -Description "Aurora PC1-PC2 encrypted Ethernet file exchange" `
        -EncryptData $true `
        -FolderEnumerationMode AccessBased `
        -FullAccess "BUILTIN\Administrators" `
        -ChangeAccess "$env:COMPUTERNAME\$ShareUser" | Out-Null
} else {
    Set-SmbShare `
        -Name $ShareName `
        -EncryptData $true `
        -FolderEnumerationMode AccessBased `
        -Force
    Revoke-SmbShareAccess `
        -Name $ShareName `
        -AccountName "Authenticated Users" `
        -Force `
        -ErrorAction SilentlyContinue | Out-Null
    Grant-SmbShareAccess `
        -Name $ShareName `
        -AccountName "$env:COMPUTERNAME\$ShareUser" `
        -AccessRight Change `
        -Force | Out-Null
}

Set-SmbServerConfiguration `
    -EnableSMB1Protocol $false `
    -EnableAuthenticateUserSharing $true `
    -EnableSecuritySignature $true `
    -Force

# Disable broad built-in SMB inbound allows. The Aurora rule below is the
# only inbound TCP 445 path and is bound to the direct Ethernet interface.
Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Direction -eq "Inbound" -and
        (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_).LocalPort -contains "445"
    } |
    Disable-NetFirewallRule

$firewallRuleName = "Aurora-SMB-Ethernet-In"
Get-NetFirewallRule -Name $firewallRuleName -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule
New-NetFirewallRule `
    -Name $firewallRuleName `
    -DisplayName "Aurora SMB over direct PC1-PC2 Ethernet" `
    -Enabled True `
    -Direction Inbound `
    -Action Allow `
    -Profile Any `
    -Protocol TCP `
    -LocalPort 445 `
    -RemoteAddress $RemoteSubnet `
    -InterfaceAlias $interface.InterfaceAlias | Out-Null

& cmdkey.exe `
    "/add:$PeerAddress" `
    "/user:$PeerComputerName\$ShareUser" `
    "/pass:$plainPassword" | Out-Null
if ($LASTEXITCODE -ne 0) {
    $credentialCommand = @"
`$password = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$SharePasswordBase64'))
& cmdkey.exe '/add:$PeerAddress' '/user:$PeerComputerName\$ShareUser' "/pass:`$password"
"@
    $encodedCredentialCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($credentialCommand)
    )
    $taskName = "Aurora-Store-SMB-Credential"
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -NonInteractive -EncodedCommand $encodedCredentialCommand"
    $principal = New-ScheduledTaskPrincipal `
        -UserId $identity `
        -LogonType Interactive `
        -RunLevel Limited
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Principal $principal `
        -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Seconds 3
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "$PeerLabel files.lnk"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "\\$PeerAddress\$ShareName"
$shortcut.Description = "Encrypted Aurora file share on $PeerLabel"
$shortcut.Save()

[pscustomobject]@{
    Computer = $env:COMPUTERNAME
    LocalAddress = $interface.IPAddress
    Interface = $interface.InterfaceAlias
    Share = "\\$($interface.IPAddress)\$ShareName"
    SharePath = $SharePath
    PeerShortcut = $shortcutPath
    ShareIdentity = "$env:COMPUTERNAME\$ShareUser"
    SMB1Enabled = (Get-SmbServerConfiguration).EnableSMB1Protocol
    EncryptionRequired = (Get-SmbShare -Name $ShareName).EncryptData
}
