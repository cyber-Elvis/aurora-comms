[CmdletBinding(DefaultParameterSetName = 'Connect')]
param(
    [Parameter(Position = 0, ParameterSetName = 'Connect')]
    [string]$Alias,

    [Parameter(ParameterSetName = 'Connect')]
    [string]$User,

    [Parameter(ParameterSetName = 'Connect')]
    [ValidateSet('modern', 'iosxr', 'sros-legacy', 'network-console')]
    [string]$Profile,

    [Parameter(ParameterSetName = 'Connect')]
    [string]$IdentityFile,

    [Parameter(ParameterSetName = 'Connect')]
    [switch]$UseCodex,

    [Parameter(ParameterSetName = 'Connect')]
    [switch]$UseClaude,

    [Parameter(ParameterSetName = 'Connect')]
    [switch]$PrintOnly,

    [Parameter(ParameterSetName = 'List')]
    [switch]$List,

    [string]$InventoryPath,

    [string]$KnownHostsFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($InventoryPath)) {
    $InventoryPath = Join-Path $scriptRoot 'inventory.yml'
}

$knownHostsFileWasDefault = [string]::IsNullOrWhiteSpace($KnownHostsFile)
if ($knownHostsFileWasDefault) {
    $KnownHostsFile = Join-Path $HOME '.ssh\aurora_known_hosts'
}

function Clean-YamlValue {
    param([string]$Value)

    $v = $Value.Trim()
    if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
        return $v.Substring(1, $v.Length - 2)
    }
    return $v
}

function Read-AuroraInventory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Inventory not found: $Path"
    }

    $nodes = New-Object System.Collections.Generic.List[hashtable]
    $current = $null

    foreach ($line in Get-Content -LiteralPath $Path) {
        $trim = $line.Trim()
        if ($trim.Length -eq 0 -or $trim.StartsWith('#') -or $trim -eq 'nodes:') {
            continue
        }

        if ($trim -match '^- +alias: +(.*)$') {
            if ($null -ne $current) {
                $nodes.Add($current)
            }
            $current = @{}
            $current.alias = Clean-YamlValue $Matches[1]
            continue
        }

        if ($null -ne $current -and $trim -match '^([A-Za-z0-9_]+): +(.*)$') {
            $current[$Matches[1]] = Clean-YamlValue $Matches[2]
        }
    }

    if ($null -ne $current) {
        $nodes.Add($current)
    }

    return $nodes
}

function Quote-Arg {
    param([string]$Arg)

    if ($Arg -match '[\s"]') {
        return '"' + ($Arg -replace '"', '\"') + '"'
    }
    return $Arg
}

function Write-InventoryList {
    param($Nodes)

    $Nodes |
        ForEach-Object {
            [pscustomobject]@{
                Alias = $_.alias
                Hostname = $_.hostname
                Host = $_.host
                Port = $_.port
                Profile = $_.profile
                User = $_.default_user
                Zone = $_.zone
                Scope = $_.credential_scope
                Status = $_.status
            }
        } |
        Sort-Object Alias |
        Format-Table -AutoSize
}

$nodes = Read-AuroraInventory -Path $InventoryPath

if ($List) {
    Write-InventoryList -Nodes $nodes
    return
}

if ([string]::IsNullOrWhiteSpace($Alias)) {
    throw "Provide an alias or use -List."
}

$node = $nodes | Where-Object { $_.alias -eq $Alias } | Select-Object -First 1
if ($null -eq $node) {
    throw "Unknown alias '$Alias'. Use -List to see known aliases."
}

if ($UseCodex -and $UseClaude) {
    throw "Choose only one automation identity: -UseCodex or -UseClaude."
}

$effectiveUser = $User
if ([string]::IsNullOrWhiteSpace($effectiveUser)) {
    if ($UseCodex) {
        $effectiveUser = 'aurora-codex'
    }
    elseif ($UseClaude) {
        $effectiveUser = 'aurora-claude'
    }
    else {
        $effectiveUser = $node.default_user
    }
}

if (($effectiveUser -eq 'aurora-codex' -or $effectiveUser -eq 'aurora-claude') -and $node.credential_scope -eq 'host') {
    throw "Refusing to use $effectiveUser against host endpoint '$Alias'. Automation node accounts must not exist on PC1, PC2, cloud hosts, or GNS3 host OSes."
}

$effectiveProfile = $Profile
if ([string]::IsNullOrWhiteSpace($effectiveProfile)) {
    $effectiveProfile = $node.profile
}

if (
    $UseCodex -and
    $effectiveProfile -eq 'iosxr' -and
    [string]::IsNullOrWhiteSpace($IdentityFile)
) {
    $IdentityFile = Join-Path $HOME '.ssh\aurora-codex-local-iosxr-rsa'
}

if ($effectiveProfile -eq 'iosxr' -and $knownHostsFileWasDefault) {
    $KnownHostsFile = Join-Path $HOME '.ssh\aurora_iosxr_known_hosts'
}

if ([string]::IsNullOrWhiteSpace($node.host) -or $node.host -eq 'TBD') {
    throw "Alias '$Alias' is not connectable yet because its host is '$($node.host)'. Update inventory.yml when the endpoint exists."
}

$port = 22
if (-not [string]::IsNullOrWhiteSpace($node.port)) {
    $port = [int]$node.port
}

if ($effectiveProfile -eq 'network-console') {
    $cmd = @('telnet.exe', $node.host, [string]$port)
}
else {
    if (-not $PrintOnly) {
        $knownHostsDir = Split-Path -Parent $KnownHostsFile
        if (-not [string]::IsNullOrWhiteSpace($knownHostsDir) -and -not (Test-Path -LiteralPath $knownHostsDir)) {
            New-Item -ItemType Directory -Path $knownHostsDir | Out-Null
        }
    }

    $cmd = @(
        'ssh.exe',
        '-p', [string]$port,
        '-l', $effectiveUser,
        '-o', "UserKnownHostsFile=$KnownHostsFile",
        '-o', 'StrictHostKeyChecking=accept-new',
        '-o', 'ServerAliveInterval=30',
        '-o', 'ServerAliveCountMax=3'
    )

    if (-not [string]::IsNullOrWhiteSpace($IdentityFile)) {
        $cmd += @('-i', $IdentityFile)
    }

    if ($node.ContainsKey('proxy_jump') -and -not [string]::IsNullOrWhiteSpace($node.proxy_jump) -and $node.proxy_jump -ne 'TBD') {
        $cmd += @('-J', $node.proxy_jump)
    }

    if ($effectiveProfile -eq 'sros-legacy') {
        $cmd += @(
            '-o', 'KexAlgorithms=+diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1,diffie-hellman-group14-sha1',
            '-o', 'HostKeyAlgorithms=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa'
        )
    }
    elseif ($effectiveProfile -eq 'iosxr') {
        # IOS-XRv 6.1.3 predates Ed25519 and can require the legacy ssh-rsa
        # signature algorithm. Keep this compatibility exception scoped to XR.
        $cmd += @(
            '-o', 'HostKeyAlgorithms=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa'
        )
    }

    $cmd += $node.host
}

$rendered = ($cmd | ForEach-Object { Quote-Arg $_ }) -join ' '

if ($PrintOnly) {
    $rendered
    return
}

Write-Host "Connecting to $($node.alias) ($($node.hostname)) as $effectiveUser using profile '$effectiveProfile'..."
& $cmd[0] @($cmd[1..($cmd.Count - 1)])
