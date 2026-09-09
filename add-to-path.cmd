@echo off
rem =============================================================================
rem  add-to-path.cmd — Add MSYS2 (gcc, pacman, bash...) to your Windows PATH.
rem  Safe to run several times: the script skips entries that are already there.
rem
rem  Double-click it right after installing MSYS2 / update-gcc, or run it from
rem  a terminal. Options of add-to-path.ps1 can be passed through, e.g.:
rem     add-to-path.cmd -Scope Machine
rem =============================================================================
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0add-to-path.ps1" %*
if "%~1"=="" pause
