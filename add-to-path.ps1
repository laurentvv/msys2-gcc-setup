#Requires -Version 5.1
<#
.SYNOPSIS
    Adds MSYS2 directories to your Windows PATH so gcc, pacman, bash and the
    MinGW toolchain can be called from any terminal (CMD, PowerShell, VS Code...).

.DESCRIPTION
    Appends (never replaces) the following directories to the selected scope's
    PATH, only if they exist and are not already present:

        <MSYS2 root>              (default C:\msys64)
        <MSYS2 root>\usr\bin      pacman, bash, coreutils...
        <MSYS2 root>\ucrt64\bin   gcc on a default MSYS2 install
        <MSYS2 root>\mingw64\bin  if present
        <MSYS2 root>\clang64\bin  if present

    The script is idempotent: running it a second time changes nothing.
    Entries are appended at the END of PATH, so Windows built-in tools
    (find, sort, tar...) always keep priority over the MSYS2 ones.
    The registry value kind (REG_EXPAND_SZ) is preserved and a
    WM_SETTINGCHANGE is broadcast so newly started programs see the change.

.PARAMETER Msys2Root
    MSYS2 installation directory. Default: the folder containing this script
    if it looks like an MSYS2 root, otherwise C:\msys64.

.PARAMETER Scope
    'User' (default, no admin rights needed) or 'Machine' (all users,
    requires an elevated PowerShell).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\add-to-path.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\add-to-path.ps1 -Scope Machine -Msys2Root D:\msys64
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

if (-not (Test-Path (Join-Path $Msys2Root 'usr\bin\pacman.exe'))) {
    Write-Warning "pacman.exe was not found under '$Msys2Root' - is this really an MSYS2 install?"
}

$candidates = @(
    $Msys2Root,
    (Join-Path $Msys2Root 'usr\bin'),
    (Join-Path $Msys2Root 'ucrt64\bin'),
    (Join-Path $Msys2Root 'mingw64\bin'),
    (Join-Path $Msys2Root 'clang64\bin')
)
function Test-DirNotEmpty {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    return @((Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue |
        Select-Object -First 1)).Count -gt 0
}
# skip empty environment stubs (e.g. mingw64\bin when that toolchain is not installed)
$dirs = @($candidates | Where-Object { Test-DirNotEmpty $_ })
if ($dirs.Count -eq 0) { throw "No MSYS2 directory found under '$Msys2Root'." }

# --- read the current PATH (registry keeps %VAR% references intact) ---------
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
    $existingNorm = @($entries | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() })

    $added = @()
    foreach ($d in $dirs) {
        $norm = $d.TrimEnd('\').ToLowerInvariant()
        if ($existingNorm -notcontains $norm) {
            $entries += $d
            $existingNorm += $norm
            $added += $d
        }
    }

    if ($added.Count -eq 0) {
        Write-Host "Nothing to do: MSYS2 is already in your $Scope PATH." -ForegroundColor Green
        return
    }

    try {
        $key.SetValue('Path', ($entries -join ';'), $kind)
    } catch [System.UnauthorizedAccessException], [System.Security.SecurityException] {
        throw "Permission denied writing the $Scope PATH. Run PowerShell 'as administrator' to use -Scope Machine."
    }
} finally {
    $key.Close()
}

# --- broadcast WM_SETTINGCHANGE so new programs pick up the new PATH --------
Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
$result = [UIntPtr]::Zero
[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001A, [UIntPtr]::Zero,
    'Environment', 0x0002, 5000, [ref]$result) | Out-Null

Write-Host "Added to your $Scope PATH:" -ForegroundColor Green
$added | ForEach-Object { Write-Host "  + $_" }
Write-Host ""
Write-Host "Restart your terminals (CMD / PowerShell / VS Code) for the change to take effect."
