[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$TaskGroup = 'AURORA-CODEX-RO'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$reservedWords = @(
    'task',
    'read',
    'write',
    'execute',
    'debug',
    'show',
    'available',
    'supported',
    'description',
    'name',
    'id'
)

$nonAssignableTaskIds = @(
    # IOS-XRv 6.1.3 reports these via `show aaa task supported`, but rejects
    # them as taskgroup read/debug grants.
    'cisco-support',
    'disallowed',
    'root-lr',
    'root-system',
    'universal'
)

$taskIds = foreach ($line in Get-Content -LiteralPath $InputPath) {
    # Accept either `show aaa task supported` tabular output or contextual-help
    # lines such as: "  basic-services     Ping, show version/privileges".
    if ($line -match '^\s{1,}([a-z][a-z0-9-]*)\s{2,}.+$') {
        $candidate = $Matches[1]
        if ($candidate -notin $reservedWords) {
            $candidate
        }
    } elseif ($line -match '^([a-z][a-z0-9-]*)\s*$') {
        $candidate = $Matches[1]
        if ($candidate -notin $reservedWords) {
            $candidate
        }
    }
}

$taskIds = @(
    $taskIds |
        Where-Object { $_ -notin $nonAssignableTaskIds } |
        Sort-Object -Unique
)
if ($taskIds.Count -eq 0) {
    throw "No IOS-XR task IDs were found in $InputPath."
}

if ('basic-services' -notin $taskIds) {
    throw "The required IOS-XR task ID 'basic-services' was not found."
}

"taskgroup $TaskGroup"
" description Full read plus basic-services and debug with no write"
" ! IOS-XRv 6.1.3 assignable task IDs: $($taskIds.Count)"
foreach ($taskId in $taskIds) {
    " task read $taskId"
}
" task execute basic-services"
foreach ($taskId in $taskIds) {
    " task debug $taskId"
}
"!"
