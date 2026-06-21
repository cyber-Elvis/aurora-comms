#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateRange(5, 100)]
    [int]$OpacityPercent = 25,

    [switch]$InstallAtLogon,
    [switch]$RemoveAtLogon,
    [switch]$Watch,

    [ValidateRange(2, 300)]
    [int]$IntervalSeconds = 10,

    [ValidateRange(0, 3600)]
    [int]$WaitSeconds = 30,

    [string]$TaskName = "Aurora-Termius-Opacity"
)

$ErrorActionPreference = "Stop"

if (-not ("Aurora.WindowOpacity" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace Aurora {
    public static class WindowOpacity {
        private const int GWL_EXSTYLE = -20;
        private const long WS_EX_LAYERED = 0x00080000L;
        private const uint LWA_ALPHA = 0x00000002;

        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

        [DllImport("user32.dll")]
        private static extern bool IsWindowVisible(IntPtr hWnd);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

        [DllImport("user32.dll")]
        private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

        [DllImport("user32.dll", EntryPoint = "GetWindowLong", SetLastError = true)]
        private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr", SetLastError = true)]
        private static extern IntPtr GetWindowLongPtr64(IntPtr hWnd, int nIndex);

        [DllImport("user32.dll", EntryPoint = "SetWindowLong", SetLastError = true)]
        private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);

        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr", SetLastError = true)]
        private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, byte bAlpha, uint dwFlags);

        private static IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex) {
            if (IntPtr.Size == 8) {
                return GetWindowLongPtr64(hWnd, nIndex);
            }
            return new IntPtr(GetWindowLong32(hWnd, nIndex));
        }

        private static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong) {
            if (IntPtr.Size == 8) {
                return SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
            }
            return new IntPtr(SetWindowLong32(hWnd, nIndex, dwNewLong.ToInt32()));
        }

        public static string[] ApplyToTermius(byte alpha) {
            List<string> results = new List<string>();

            EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
                if (!IsWindowVisible(hWnd)) {
                    return true;
                }

                uint pid;
                GetWindowThreadProcessId(hWnd, out pid);
                if (pid == 0) {
                    return true;
                }

                Process proc;
                try {
                    proc = Process.GetProcessById((int)pid);
                } catch {
                    return true;
                }

                StringBuilder titleBuilder = new StringBuilder(512);
                GetWindowText(hWnd, titleBuilder, titleBuilder.Capacity);
                string title = titleBuilder.ToString();
                string procName = proc.ProcessName ?? "";

                bool isTermius =
                    procName.IndexOf("Termius", StringComparison.OrdinalIgnoreCase) >= 0 ||
                    title.IndexOf("Termius", StringComparison.OrdinalIgnoreCase) >= 0;

                if (!isTermius) {
                    return true;
                }

                long exStyle = GetWindowLongPtr(hWnd, GWL_EXSTYLE).ToInt64();
                SetWindowLongPtr(hWnd, GWL_EXSTYLE, new IntPtr(exStyle | WS_EX_LAYERED));

                if (SetLayeredWindowAttributes(hWnd, 0, alpha, LWA_ALPHA)) {
                    if (String.IsNullOrWhiteSpace(title)) {
                        title = "(untitled)";
                    }
                    results.Add(String.Format("PID {0}, HWND 0x{1:X}, title: {2}", pid, hWnd.ToInt64(), title));
                }

                return true;
            }, IntPtr.Zero);

            return results.ToArray();
        }
    }
}
"@
}

function Get-Alpha {
    param([Parameter(Mandatory = $true)][int]$Percent)
    return [byte][Math]::Round(255 * ($Percent / 100.0))
}

function Invoke-TermiusOpacity {
    param([Parameter(Mandatory = $true)][int]$Percent)

    $alpha = Get-Alpha -Percent $Percent
    $results = [Aurora.WindowOpacity]::ApplyToTermius($alpha)
    foreach ($result in $results) {
        Write-Host "Set Termius opacity to $Percent%: $result"
    }
    return $results.Count
}

function Install-OpacityTask {
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        throw "InstallAtLogon requires this script to be saved as a .ps1 file."
    }

    $userId = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { $env:USERNAME }
    $argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -OpacityPercent $OpacityPercent -Watch -IntervalSeconds $IntervalSeconds -WaitSeconds 300"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $argument
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $userId
    $principal = New-ScheduledTaskPrincipal -UserId $userId -LogonType Interactive -RunLevel LeastPrivilege
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description "Aurora lab helper: keep Termius at $OpacityPercent percent opacity for the logged-in PC2 desktop." `
        -Force | Out-Null

    Write-Host "Installed scheduled task: $TaskName"
}

if ($RemoveAtLogon) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed scheduled task: $TaskName"
    exit 0
}

if ($InstallAtLogon) {
    Install-OpacityTask
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
do {
    $changed = Invoke-TermiusOpacity -Percent $OpacityPercent
    if ($changed -gt 0 -and -not $Watch) {
        exit 0
    }

    if (-not $Watch -and (Get-Date) -ge $deadline) {
        Write-Warning "No visible Termius window found. Start Termius and rerun this script."
        exit 2
    }

    Start-Sleep -Seconds $IntervalSeconds
} while ($Watch -or (Get-Date) -lt $deadline)
