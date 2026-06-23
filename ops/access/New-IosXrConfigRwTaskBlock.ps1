<#
.SYNOPSIS
    Generate the IOS-XRv 6.1.3 read+write+execute task block for the
    aurora-automation Ansible config-as-code service account.

.DESCRIPTION
    Sibling to New-IosXrReadDebugTaskBlock.ps1 (which builds the read-only
    aurora-codex role). This emits a config-push role:

      - task read  <id>   for every assignable task ID
      - task write <id>   for every assignable task ID NOT in -WriteExclude
      - task execute basic-services, filesystem, system
      - NO debug grants

    `filesystem` execute is included because the cisco.iosxr connect probe runs
    `show version | utility head -n 20`, and the `head` utility is gated above
    `basic-services` execute (which the read-only account already proves is
    insufficient). Confirm on-box per the MOP and escalate the execute set only
    if the probe still fails.

    The default -WriteExclude withholds write on the security-sensitive task IDs
    so automation cannot rewrite its own authorization, touch lawful intercept,
    or manage key material:
      aaa    - no user/RBAC changes by automation (no self-escalation)
      li     - lawful intercept is never automated
      crypto - key/certificate material stays with break-glass

    Input is the captured `show aaa task supported` output from the target image.

.EXAMPLE
    .\New-IosXrConfigRwTaskBlock.ps1 -InputPath .\show-aaa-task-supported.txt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [string]$TaskGroup = 'AURORA-AUTOMATION-RW',

    [string[]]$WriteExclude = @('aaa', 'li', 'crypto')
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
    # them as taskgroup grants.
    'cisco-support',
    'disallowed',
    'root-lr',
    'root-system',
    'ssh',
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

$writeIds = @($taskIds | Where-Object { $_ -notin $WriteExclude })
$writeExcluded = @($taskIds | Where-Object { $_ -in $WriteExclude })

"taskgroup $TaskGroup"
" description Ansible config-as-code: read all, write network, no aaa/li/crypto, no debug"
" ! IOS-XRv 6.1.3 assignable task IDs: $($taskIds.Count); write grants: $($writeIds.Count)"
" ! write withheld on: $($writeExcluded -join ', ')"
foreach ($taskId in $taskIds) {
    " task read $taskId"
}
foreach ($taskId in $writeIds) {
    " task write $taskId"
}
" task execute basic-services"
" task execute filesystem"
" task execute system"
"!"
