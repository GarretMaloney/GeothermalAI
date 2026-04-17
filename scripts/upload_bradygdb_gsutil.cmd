@echo off
setlocal
REM Upload BradyGDB (~178 GB) to GCS for Colab. Safe to re-run: gsutil rsync is incremental.
REM Log: repo exports folder. Close this window only after upload finishes (or use Task Manager).

set "SOURCE=D:\GIS Final Project\BradyGDB"
set "DEST=gs://gis-final-project/GIS Final Project/BradyGDB"
set "LOG=%~dp0..\exports\gsutil_bradygdb_upload.log"

set "GSUTIL=%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
if not exist "%GSUTIL%" set "GSUTIL=%ProgramFiles(x86)%\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
if not exist "%GSUTIL%" (
  echo gsutil.cmd not found. Install Google Cloud SDK.
  exit /b 1
)

if not exist "%~dp0..\exports" mkdir "%~dp0..\exports"

echo Logging to: %LOG%
echo Syncing "%SOURCE%" -^> "%DEST%"
echo Started: %DATE% %TIME%
echo.

>>"%LOG%" echo ===== %DATE% %TIME% =====
>>"%LOG%" echo "%SOURCE%" -^> "%DEST%"
"%GSUTIL%" -m rsync -r "%SOURCE%" "%DEST%" >>"%LOG%" 2>&1
set "EC=%ERRORLEVEL%"
echo.
echo Finished: %DATE% %TIME% exit=%EC%
>>"%LOG%" echo Finished: %DATE% %TIME% exit=%EC%
echo Full log: %LOG%
exit /b %EC%
