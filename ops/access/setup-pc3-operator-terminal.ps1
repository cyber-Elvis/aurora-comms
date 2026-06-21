#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ExpectedHostname = "forty3s-PC3",
    [string]$Gns3JumpHost = "100.118.0.46",
    [string]$Pc1JumpHost = "100.116.32.29",
    [string]$Pc1JumpUser = "aurora-operator",
    [switch]$SkipHostnameCheck,
    [switch]$ForceConfig
)

$ErrorActionPreference = "Stop"

$actualHostname = [System.Net.Dns]::GetHostName()
if (-not $SkipHostnameCheck -and $actualHostname -ne $ExpectedHostname) {
    throw "This bootstrap is intended for $ExpectedHostname, but the current host is $actualHostname. Use -SkipHostnameCheck only after confirming the target."
}

foreach ($command in "ssh.exe", "ssh-keygen.exe", "tailscale.exe") {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $command"
    }
}

$sshDirectory = Join-Path $HOME ".ssh"
New-Item -ItemType Directory -Path $sshDirectory -Force | Out-Null

$jumpKey = Join-Path $sshDirectory "aurora-pc3-jump-ed25519"
$nodeKey = Join-Path $sshDirectory "aurora-pc3-node-admin-ed25519"
$knownHosts = Join-Path $sshDirectory "aurora_known_hosts"
$configPath = Join-Path $sshDirectory "aurora_pc3_config"

function Ensure-OperatorKey {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Comment
    )

    if (Test-Path -LiteralPath $Path) {
        Write-Host "Keeping existing key: $Path"
        return
    }

    Write-Host ""
    Write-Host "Creating $Path"
    Write-Host "Choose a strong passphrase when ssh-keygen prompts."
    & ssh-keygen.exe -t ed25519 -a 100 -f $Path -C $Comment
    if ($LASTEXITCODE -ne 0) {
        throw "ssh-keygen failed for $Path"
    }
}

Ensure-OperatorKey -Path $jumpKey -Comment "aurora-pc3-jump"
Ensure-OperatorKey -Path $nodeKey -Comment "aurora-pc3-node-admin"

if ((Test-Path -LiteralPath $configPath) -and -not $ForceConfig) {
    Write-Host "Keeping existing SSH validation config: $configPath"
} else {
    $jumpKeyConfig = $jumpKey -replace "\\", "/"
    $nodeKeyConfig = $nodeKey -replace "\\", "/"
    $knownHostsConfig = $knownHosts -replace "\\", "/"

    $config = @"
Host pc2-gns3
    HostName $Gns3JumpHost
    User gns3
    IdentityFile $jumpKeyConfig
    IdentitiesOnly yes
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host mel-p1
    HostName 10.255.191.11
    User admin
    IdentityFile $nodeKeyConfig
    IdentitiesOnly yes
    ProxyJump pc2-gns3
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new

Host mel-pe1
    HostName 10.255.191.12
    User admin
    IdentityFile $nodeKeyConfig
    IdentitiesOnly yes
    ProxyJump pc2-gns3
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new

Host gel-pe1
    HostName 10.255.191.15
    User admin
    IdentityFile $nodeKeyConfig
    IdentitiesOnly yes
    ProxyJump pc2-gns3
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new

Host adl-pe1
    HostName 10.255.191.17
    User admin
    IdentityFile $nodeKeyConfig
    IdentitiesOnly yes
    ProxyJump pc2-gns3
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new

Host pc1-lab-jump
    HostName $Pc1JumpHost
    User $Pc1JumpUser
    IdentityFile $jumpKeyConfig
    IdentitiesOnly yes
    UserKnownHostsFile $knownHostsConfig
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
    ServerAliveCountMax 3
"@

    Set-Content -LiteralPath $configPath -Value $config -Encoding ascii
    Write-Host "Wrote SSH validation config: $configPath"
}

Write-Host ""
Write-Host "== PC3 Tailscale identity =="
& tailscale.exe ip -4

Write-Host ""
Write-Host "== Public key for Linux jump hosts =="
Get-Content -LiteralPath "$jumpKey.pub"

Write-Host ""
Write-Host "== Public key for lab-node admin accounts =="
Get-Content -LiteralPath "$nodeKey.pub"

Write-Host ""
Write-Host "After the public keys are installed, validate Region A with:"
Write-Host "  ssh.exe -F `"$configPath`" pc2-gns3"
Write-Host "  ssh.exe -F `"$configPath`" mel-p1"
Write-Host ""
Write-Host "In Termius, create separate identities for the jump key and node-admin key."
Write-Host "Do not copy aurora-codex or aurora-claude private keys onto PC3."
