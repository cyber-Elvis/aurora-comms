#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$PublicInterfaceAlias = "Wi-Fi",
    [string]$PrivateInterfaceAlias = "Ethernet",
    [string]$PowerToysTaskName = "Aurora-Start-PowerToys-Interactive",
    [switch]$ReapplySharing
)

$ErrorActionPreference = "Stop"

function Show-NetworkState {
    Write-Host ""
    Write-Host "== Adapters =="
    Get-NetAdapter |
        Select-Object Name, InterfaceDescription, Status, LinkSpeed |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "== IPv4 configuration =="
    Get-NetIPConfiguration |
        Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer |
        Format-List

    Write-Host ""
    Write-Host "== Services =="
    Get-Service -Name SharedAccess, Tailscale |
        Select-Object Name, Status, StartType |
        Format-Table -AutoSize
}

function Get-SharingConnection {
    param(
        [Parameter(Mandatory = $true)]$Manager,
        [Parameter(Mandatory = $true)][string]$Alias
    )

    foreach ($connection in $Manager.EnumEveryConnection()) {
        $properties = $Manager.NetConnectionProps($connection)
        if ($properties.Name -eq $Alias) {
            return $connection
        }
    }

    throw "Internet Connection Sharing interface not found: $Alias"
}

Show-NetworkState

$publicAdapter = Get-NetAdapter -Name $PublicInterfaceAlias -ErrorAction Stop
$privateAdapter = Get-NetAdapter -Name $PrivateInterfaceAlias -ErrorAction Stop

if ($publicAdapter.Status -ne "Up") {
    throw "Public/upstream adapter '$PublicInterfaceAlias' is not Up. Restore its Wi-Fi connection before repairing ICS."
}

if ($privateAdapter.Status -ne "Up") {
    throw "Private/lab adapter '$PrivateInterfaceAlias' is not Up."
}

Set-Service -Name SharedAccess -StartupType Automatic

if ($ReapplySharing) {
    Write-Host ""
    Write-Host "Reapplying Internet Connection Sharing:"
    Write-Host "  Public:  $PublicInterfaceAlias"
    Write-Host "  Private: $PrivateInterfaceAlias"

    $manager = New-Object -ComObject HNetCfg.HNetShare
    $publicConnection = Get-SharingConnection -Manager $manager -Alias $PublicInterfaceAlias
    $privateConnection = Get-SharingConnection -Manager $manager -Alias $PrivateInterfaceAlias
    $publicConfig = $manager.INetSharingConfigurationForINetConnection($publicConnection)
    $privateConfig = $manager.INetSharingConfigurationForINetConnection($privateConnection)

    if ($publicConfig.SharingEnabled) {
        $publicConfig.DisableSharing()
    }
    if ($privateConfig.SharingEnabled) {
        $privateConfig.DisableSharing()
    }

    # Restart before enabling sharing. Restarting SharedAccess after these
    # bindings are applied leaves the COM flags set but tears down NAT/DNS.
    Restart-Service -Name SharedAccess -Force
    Start-Sleep -Seconds 2

    $manager = New-Object -ComObject HNetCfg.HNetShare
    $publicConnection = Get-SharingConnection -Manager $manager -Alias $PublicInterfaceAlias
    $privateConnection = Get-SharingConnection -Manager $manager -Alias $PrivateInterfaceAlias
    $publicConfig = $manager.INetSharingConfigurationForINetConnection($publicConnection)
    $privateConfig = $manager.INetSharingConfigurationForINetConnection($privateConnection)

    # 0 = public/upstream, 1 = private/home-network connection.
    $publicConfig.EnableSharing(0)
    Start-Sleep -Seconds 2
    $privateConfig.EnableSharing(1)
}
else {
    Restart-Service -Name SharedAccess -Force
}

$tailscale = Get-Service -Name Tailscale -ErrorAction SilentlyContinue
if ($tailscale -and $tailscale.Status -ne "Running") {
    Start-Service -Name Tailscale
}

Clear-DnsClientCache

if ($ReapplySharing) {
    $powerToysTask = Get-ScheduledTask -TaskName $PowerToysTaskName -ErrorAction SilentlyContinue
    if ($powerToysTask) {
        Write-Host ""
        Write-Host "Restarting PowerToys after the Ethernet/ICS reset."

        if ($powerToysTask.State -eq "Running") {
            Stop-ScheduledTask -TaskName $PowerToysTaskName
        }

        Get-Process -Name @(
            "PowerToys.MouseWithoutBordersHelper",
            "PowerToys.MouseWithoutBorders",
            "PowerToys"
        ) -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2

        try {
            Start-ScheduledTask -TaskName $PowerToysTaskName
        }
        catch {
            Write-Warning "PowerToys could not start before interactive logon. Its logon trigger remains installed."
        }
    }
}

Start-Sleep -Seconds 5

Show-NetworkState

Write-Host ""
Write-Host "== PC2 connectivity checks =="
Test-NetConnection 1.1.1.1 -InformationLevel Detailed
Resolve-DnsName login.tailscale.com -ErrorAction Continue |
    Select-Object -First 4 Name, Type, IPAddress
& tailscale.exe status

Write-Host ""
Write-Host "Expected private-side state:"
Write-Host "  $PrivateInterfaceAlias owns 192.168.137.1/24."
Write-Host "  PC1 receives 192.168.137.x with gateway/DNS 192.168.137.1."
