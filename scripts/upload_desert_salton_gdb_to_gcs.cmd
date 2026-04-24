@echo off
setlocal
REM Double-click or:  scripts\upload_desert_salton_gdb_to_gcs.cmd
REM Calls the PowerShell uploader (live gsutil progress + logs under exports\).

cd /d "%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0upload_desert_salton_gdb_to_gcs.ps1"
set "EC=%ERRORLEVEL%"
echo.
echo Exit code: %EC%
exit /b %EC%
