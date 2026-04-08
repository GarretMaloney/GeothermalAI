@echo off
setlocal
set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"

set "GDB=%USERPROFILE%\GIS Final Project\1303\DOE_GDB"
set "OUT=%REPO%\exports\inventory_1303_full.json"

set "CONDA=%USERPROFILE%\anaconda3\Scripts\conda.exe"
if not exist "%CONDA%" set "CONDA=%USERPROFILE%\miniconda3\Scripts\conda.exe"
if not exist "%CONDA%" (
  echo conda.exe not found. Install Anaconda/Miniconda or edit CONDA in this file.
  exit /b 1
)

"%CONDA%" run -n geothermal-gis python "%REPO%\scripts\inventory_gdbs.py" --root "%GDB%" -o "%OUT%"
if errorlevel 1 exit /b 1

"%CONDA%" run -n geothermal-gis python "%REPO%\scripts\export_gdb_rasters_to_geotiff.py" --inventory "%OUT%" --out-dir "%REPO%\exports\geotiff_1303"
exit /b %ERRORLEVEL%
