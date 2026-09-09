#Requires -Version 5.1
<#
.SYNOPSIS
    Removes the MSYS2 directories that add-to-path.ps1 added from your PATH.

.DESCRIPTION
    Deletes every PATH entry located under the MSYS2 root (usr\bin,
    ucrt64\bin, mingw64\bin, ...) in the selected scope. Other entries,
    and their order, are left untouched.

.PARAMETER Msys2Root
    MSYS2 installation directory. Default: the folder containing this script
    if it looks like an MSYS2 root, otherwise C:\msys64.

.PARAMETER Scope
    'User' (default) or 'Machine' (requires an elevated PowerShell).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\remove-from-path.ps1
#>
[CmdletBinding()]
param(
    [string]$Msys2Root,
    [ValidateSet('User', 'Machine')]
    [string]$Scope = 'User'
)

$ErrorActionPreference = 'Stop'

function Find-Msys2Root {
    param([string]$ScriptDir)
    if ($ScriptDir -and (Test-Path (Join-Path $ScriptDir 'usr\bin\pacman.exe'))) {
        return $ScriptDir
    }
    return 'C:\msys64'
}

if (-not $Msys2Root) { $Msys2Root = Find-Msys2Root $PSScriptRoot }
$resolved = Resolve-Path $Msys2Root -ErrorAction SilentlyContinue
if ($resolved) { $Msys2Root = $resolved.Path }
$rootNorm = $Msys2Root.TrimEnd('\').ToLowerInvariant()

if ($Scope -eq 'User') {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
} else {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true)
}
if (-not $key) { throw "Cannot open the $Scope environment registry key." }

try {
    $current = [string]$key.GetValue('Path', '')
    $kind = try { $key.GetValueKind('Path') } catch { [Microsoft.Win32.RegistryValueKind]::ExpandString }

    $entries = @($current -split ';' | Where-Object { $_ })
    $kept = @($entries | Where-Object { -not $_.TrimEnd('\').ToLowerInvariant().StartsWith($rootNorm) })
    $removed = @($entries | Where-Object { $_.TrimEnd('\').ToLowerInvariant().StartsWith($rootNorm) })

    if ($removed.Count -eq 0) {
        Write-Host "Nothing to remove: no MSYS2 entry found in your $Scope PATH." -ForegroundColor Green
        return
    }

    try {
        $key.SetValue('Path', ($kept -join ';'), $kind)
    } catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
        throw "Permission denied writing the $Scope PATH. Run PowerShell 'as administrator' to use -Scope Machine."
    }
} finally {
    $key.Close()
}

Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
$result = [UIntPtr]::Zero
[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero,
    'Environment', 0x0002, 5000, [ref]$result) | Out-Null

Write-Host "Removed from your $Scope PATH:" -ForegroundColor Yellow
$removed | ForEach-Object { Write-Host "  - $_" }
