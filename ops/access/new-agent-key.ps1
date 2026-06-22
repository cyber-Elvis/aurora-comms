[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('codex', 'claude')]
    [string]$Agent,

    [Parameter(Mandatory = $true)]
    [ValidateSet('local', 'cloud', 'devnet')]
    [string]$Zone,

    [ValidateSet('ed25519', 'rsa')]
    [string]$KeyType = 'ed25519',

    [ValidateRange(2048, 8192)]
    [int]$RsaBits = 3072,

    [string]$NameSuffix = '',

    [string]$OutDir = (Join-Path $HOME '.ssh'),

    [string]$Passphrase = '',

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue)) {
    throw "ssh-keygen.exe was not found in PATH."
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$suffix = if ([string]::IsNullOrWhiteSpace($NameSuffix)) { '' } else { "-$NameSuffix" }
$baseName = "aurora-$Agent-$Zone$suffix-$KeyType"
$privateKey = Join-Path $OutDir $baseName
$publicKey = "$privateKey.pub"

if ((Test-Path -LiteralPath $privateKey) -and -not $Force) {
    throw "Key already exists: $privateKey. Use -Force only if you intentionally want to replace it."
}

if ((Test-Path -LiteralPath $publicKey) -and -not $Force) {
    throw "Public key already exists: $publicKey. Use -Force only if you intentionally want to replace it."
}

if ($Force) {
    Remove-Item -LiteralPath $privateKey -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $publicKey -Force -ErrorAction SilentlyContinue
}

$comment = "aurora-$Agent-$Zone$suffix"
$sshPassphrase = if ($Passphrase.Length -eq 0) { '""' } else { $Passphrase }
$keyArguments = @('-t', $KeyType)
if ($KeyType -eq 'rsa') {
    $keyArguments += @('-b', [string]$RsaBits)
}
$keyArguments += @('-f', $privateKey, '-N', $sshPassphrase, '-C', $comment)
& ssh-keygen.exe @keyArguments

Write-Host ""
Write-Host "Private key: $privateKey"
Write-Host "Public key : $publicKey"
Write-Host ""
Write-Host "Public key content:"
Get-Content -LiteralPath $publicKey
Write-Host ""
Write-Host "Use with:"
Write-Host ".\ops\access\aurora-ssh.ps1 <alias> -Use$((Get-Culture).TextInfo.ToTitleCase($Agent)) -IdentityFile $privateKey"
