@echo off
setlocal
REM Edit these three, then run from cmd.
set "BUCKET=YOUR_BUCKET_NAME"
set "PREFIX=doe-gdb"
set "SOURCE=%USERPROFILE%\GIS Final Project\1303\DOE_GDB"

set "GSUTIL=%ProgramFiles(x86)%\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
if not exist "%GSUTIL%" set "GSUTIL=%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
if not exist "%GSUTIL%" (
  echo Install Google Cloud SDK and gsutil, or edit GSUTIL path in this file.
  exit /b 1
)

echo Syncing "%SOURCE%" to gs://%BUCKET%/%PREFIX%/
"%GSUTIL%" -m rsync -r "%SOURCE%" "gs://%BUCKET%/%PREFIX%/"
exit /b %ERRORLEVEL%
