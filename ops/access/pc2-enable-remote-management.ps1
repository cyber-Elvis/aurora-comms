#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$EnableWinRM,
    [switch]$InstallStartupRepair,
    [switch]$SkipStartupTask,
    [string]$StartupTaskName = "Aurora-Repair-Remote-Management",
    [string[]]$AllowedRemoteAddress = @(
        "100.64.0.0/10",
        "192.168.137.0/24",
        "100.88.225.123",
        "192.168.137.235"
    ),
    # Public keys authorized for admin SSH (administrators_authorized_keys).
    # aurora-pc2-host = PC1 automation key; its private key stays on PC1 only.
    [string[]]$AuthorizedKey = @(
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINTUzwLcSkxhgYjCzLk4rufS1YWirYbjDlsGps8KutGK aurora-pc2-host"
    )
)

$ErrorActionPreference = "Stop"

function Ensure-FirewallRule {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][int]$Port
    )

    $rule = Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue
    if ($rule) {
        Remove-NetFirewallRule -Name $Name
    }

    New-NetFirewallRule `
        -Name $Name `
        -DisplayName $DisplayName `
        -Enabled True `
        -Direction Inbound `
        -Action Allow `
        -Profile Any `
        -Protocol TCP `
        -LocalPort $Port `
        -RemoteAddress $AllowedRemoteAddress | Out-Null
}

function Restrict-FirewallRuleSources {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]$Rule
    )

    process {
        if (-not $Rule) {
            return
        }

        Set-NetFirewallRule `
            -Name $Rule.Name `
            -Enabled True `
            -Action Allow `
            -Profile Any

        Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $Rule |
            Set-NetFirewallAddressFilter -RemoteAddress $AllowedRemoteAddress
    }
}

function Get-OpenSshFirewallRules {
    $rules = @()
    $rules += Get-NetFirewallRule -DisplayGroup "OpenSSH Server" -ErrorAction SilentlyContinue
    $rules += Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    $rules += Get-NetFirewallRule -DisplayName "OpenSSH SSH Server*" -ErrorAction SilentlyContinue

    $rules |
        Where-Object { $_ -and $_.Direction -eq "Inbound" } |
        Sort-Object -Property Name -Unique
}

function Get-WinRMFirewallRules {
    $rules = @()
    $rules += Get-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
    $rules += Get-NetFirewallRule -Name "WINRM-HTTP-In-TCP*" -ErrorAction SilentlyContinue

    $rules |
        Where-Object { $_ -and $_.Direction -eq "Inbound" } |
        Sort-Object -Property Name -Unique
}

function Ensure-OpenSshServer {
    $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if (-not $sshd) {
        $capability = Get-WindowsCapability -Online -Name "OpenSSH.Server~~~~0.0.1.0" -ErrorAction SilentlyContinue
        if ($capability -and $capability.State -ne "Installed") {
            Add-WindowsCapability -Online -Name $capability.Name | Out-Null
        }
        $sshd = Get-Service -Name sshd -ErrorAction SilentlyContinue
    }

    if (-not $sshd) {
        throw "OpenSSH Server is not installed and could not be installed automatically."
    }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd

    $agent = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
    if ($agent) {
        Set-Service -Name ssh-agent -StartupType Manual
    }

    Ensure-FirewallRule `
        -Name "Aurora-OpenSSH-Inbound" `
        -DisplayName "Aurora OpenSSH inbound from Tailscale and lab link" `
        -Port 22

    Get-OpenSshFirewallRules | Restrict-FirewallRuleSources
}

function Ensure-AdminAuthorizedKey {
    param([Parameter(Mandatory = $true)][string[]]$PublicKey)

    $keys = @($PublicKey |
        ForEach-Object { ($_ -replace "`r", "").Trim() } |
        Where-Object { $_ -and $_ -notmatch '^\s*#' })
    if (-not $keys) {
        Write-Warning "No authorized public keys supplied; skipping key install."
        return
    }

    $sshDir = Join-Path $env:ProgramData "ssh"
    $authFile = Join-Path $sshDir "administrators_authorized_keys"
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

    $existing = @()
    if (Test-Path $authFile) {
        # @() forces an array even for a single-line file; otherwise Get-Content
        # returns a scalar string and `+ $keys` concatenates instead of appending.
        $existing = @(Get-Content -LiteralPath $authFile -ErrorAction SilentlyContinue |
            ForEach-Object { ($_ -replace "`r", "").Trim() } |
            Where-Object { $_ })
    }

    $merged = @($existing + $keys | Select-Object -Unique)
    $added = @($keys | Where-Object { $existing -notcontains $_ })

    # Windows OpenSSH requires LF-friendly content; write UTF8 without BOM.
    $content = ($merged -join "`n") + "`n"
    [System.IO.File]::WriteAllText($authFile, $content, (New-Object System.Text.UTF8Encoding($false)))

    # administrators_authorized_keys must be owned/writable only by
    # Administrators and SYSTEM, or sshd silently ignores it.
    icacls $authFile /inheritance:r | Out-Null
    icacls $authFile /grant "Administrators:F" "SYSTEM:F" | Out-Null

    if ($added.Count -gt 0) {
        Write-Host ("Authorized {0} new key(s):" -f $added.Count)
        $added | ForEach-Object {
            $parts = $_ -split '\s+'
            Write-Host ("  + {0} ... {1}" -f $parts[0], ($parts[-1]))
        }
    } else {
        Write-Host "All supplied keys already authorized (no change)."
    }
}

function Enable-InboundAllowRules {
    Set-NetFirewallProfile `
        -Profile Domain, Private, Public `
        -Enabled True `
        -DefaultInboundAction Block `
        -AllowInboundRules True `
        -AllowLocalFirewallRules True
}

function Ensure-WinRM {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null
    Set-Service -Name WinRM -StartupType Automatic
    Start-Service -Name WinRM

    Ensure-FirewallRule `
        -Name "Aurora-WinRM-HTTP-Inbound" `
        -DisplayName "Aurora WinRM HTTP inbound from Tailscale and lab link" `
        -Port 5985

    Get-WinRMFirewallRules | Restrict-FirewallRuleSources
}

function Install-StartupRepairTask {
    $installDirectory = Join-Path $env:ProgramData "Aurora"
    $installedScript = Join-Path $installDirectory "enable-remote-management.ps1"

    New-Item -ItemType Directory -Path $installDirectory -Force | Out-Null
    Copy-Item -LiteralPath $PSCommandPath -Destination $installedScript -Force

    $addressLiteral = ($AllowedRemoteAddress | ForEach-Object {
        "'{0}'" -f ($_ -replace "'", "''")
    }) -join ","
    $winRmArgument = if ($EnableWinRM) { " -EnableWinRM" } else { "" }
    $repairCommand = "& '$($installedScript -replace "'", "''")'$winRmArgument -SkipStartupTask -AllowedRemoteAddress @($addressLiteral)"
    $encodedCommand = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($repairCommand)
    )

    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedCommand"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask `
        -TaskName $StartupTaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Reassert Aurora SSH, WinRM, and restricted firewall rules after startup." `
        -Force | Out-Null

    Write-Host "Installed startup repair task: $StartupTaskName"
    Write-Host "Installed repair script: $installedScript"
}

function Show-Listener {
    param([Parameter(Mandatory = $true)][int]$Port)

    $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    $listener = $listeners | Select-Object -First 1
    if ($listener) {
        Write-Host "TCP $Port listening"
        $listeners | Select-Object LocalAddress, LocalPort, State, OwningProcess | Format-Table -AutoSize
    } else {
        Write-Warning "TCP $Port is not listening"
    }
}

function Show-FirewallRule {
    param([Parameter(Mandatory = $true)][string]$Name)

    $rule = Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue
    if (-not $rule) {
        Write-Warning "Firewall rule $Name is missing"
        return
    }

    $rule | Format-Table Name, Enabled, Direction, Action, Profile -AutoSize
    Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule |
        Format-Table Protocol, LocalPort -AutoSize
    Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule |
        Format-Table RemoteAddress -AutoSize
}

Enable-InboundAllowRules
Ensure-OpenSshServer
Ensure-AdminAuthorizedKey -PublicKey $AuthorizedKey

if ($EnableWinRM) {
    Ensure-WinRM
}

if ($InstallStartupRepair -and -not $SkipStartupTask) {
    Install-StartupRepairTask
}

Write-Host ""
Write-Host ("== Aurora remote management status: {0} ==" -f $env:COMPUTERNAME)
Write-Host ("Allowed remote addresses: {0}" -f ($AllowedRemoteAddress -join ", "))
Get-Service -Name sshd, WinRM -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType |
    Format-Table -AutoSize

Get-NetFirewallProfile |
    Select-Object Name, Enabled, DefaultInboundAction, AllowInboundRules, AllowLocalFirewallRules |
    Format-Table -AutoSize

Show-Listener -Port 22
Show-FirewallRule -Name "Aurora-OpenSSH-Inbound"
if ($EnableWinRM) {
    Show-Listener -Port 5985
    Show-FirewallRule -Name "Aurora-WinRM-HTTP-Inbound"
}

Write-Host ""
Write-Host "Authorized admin keys (administrators_authorized_keys):"
$authFile = Join-Path $env:ProgramData "ssh\administrators_authorized_keys"
if (Test-Path $authFile) {
    Get-Content -LiteralPath $authFile |
        Where-Object { $_.Trim() } |
        ForEach-Object { $p = $_ -split '\s+'; Write-Host ("  {0} ... {1}" -f $p[0], $p[-1]) }
} else {
    Write-Warning "  (none - administrators_authorized_keys missing)"
}

Write-Host ""
Write-Host "From PC1, verify with:"
Write-Host "  Test-NetConnection 192.168.137.1 -Port 22"
Write-Host ("  ssh -i `$HOME\.ssh\aurora-pc2-host-ed25519 {0}@192.168.137.1 ""whoami; hostname""" -f $env:USERNAME)
if ($EnableWinRM) {
    Write-Host "  Test-NetConnection 192.168.137.1 -Port 5985"
}
