# Run from repo root (or anywhere). Creates conda env `geothermal-gis` from environment.yml.
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Conda = Join-Path $env:USERPROFILE "anaconda3\Scripts\conda.exe"
if (-not (Test-Path $Conda)) { $Conda = Join-Path $env:USERPROFILE "miniconda3\Scripts\conda.exe" }
if (-not (Test-Path $Conda)) { Write-Error "conda.exe not found. Install Miniconda/Anaconda or edit path." }
& $Conda env remove -n geothermal-gis -y 2>$null
& $Conda create -n geothermal-gis -c conda-forge python=3.11 gdal fiona rasterio numpy -y --solver=libmamba
Write-Host "Done. Activate: conda activate geothermal-gis"
