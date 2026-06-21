#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+2oqVIv4gXdl79AeFiHrKIR5mlOxp202WNYC1Cgpjrt1GuriqXf3CfiQCQrJmc9tNDPwvNUjbDkyY6mUV/pzDhEWuRBX+TaVQD9J9gc47nBuRqRVfz4s7IIpIBvQFQDlQFB1ix0XY22pHX7XqYL9J2LRZDdqCFHLTGfcutKS36Q1ExlqK1LwHCob1wEmT54G0TYL8DnKXR0nSU4fMZfmeW71cNwNu4oBMSYh5dAlJHteYd+7a5hm2aIszlYgvZjt+dbGkzS2w6/CsXq4tS6Gs+VrNhAD4EYm1RVlV07rVzbfDGMzSsu0qXQygaHj2r7llUQWr/YIiS1IABD0KitGR PC1-Elvis"
$sshDirectory = Join-Path $env:ProgramData "ssh"
$authorizedKeys = Join-Path $sshDirectory "administrators_authorized_keys"
$userSshDirectory = Join-Path $HOME ".ssh"
$userAuthorizedKeys = Join-Path $userSshDirectory "authorized_keys"

New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $authorizedKeys)) {
    New-Item -ItemType File -Path $authorizedKeys -Force | Out-Null
}

$existingKeys = Get-Content -LiteralPath $authorizedKeys -ErrorAction SilentlyContinue
if ($existingKeys -notcontains $publicKey) {
    Add-Content -LiteralPath $authorizedKeys -Value $publicKey -Encoding ascii
}

New-Item -ItemType Directory -Path $userSshDirectory -Force | Out-Null
if (-not (Test-Path -LiteralPath $userAuthorizedKeys)) {
    New-Item -ItemType File -Path $userAuthorizedKeys -Force | Out-Null
}

$existingUserKeys = Get-Content -LiteralPath $userAuthorizedKeys -ErrorAction SilentlyContinue
if ($existingUserKeys -notcontains $publicKey) {
    Add-Content -LiteralPath $userAuthorizedKeys -Value $publicKey -Encoding ascii
}

& icacls.exe $authorizedKeys /inheritance:r /grant "*S-1-5-32-544:F" /grant "SYSTEM:F" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to set OpenSSH authorized-key permissions."
}

$currentUserSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $userSshDirectory /inheritance:r /grant "*${currentUserSid}:(OI)(CI)F" /grant "*S-1-5-18:(OI)(CI)F" | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to set the per-user SSH directory permissions."
}

Set-Service -Name sshd -StartupType Automatic
Restart-Service -Name sshd

Write-Host "Authorized PC1 key on $env:COMPUTERNAME"
& ssh-keygen.exe -lf $authorizedKeys
& ssh-keygen.exe -lf $userAuthorizedKeys
