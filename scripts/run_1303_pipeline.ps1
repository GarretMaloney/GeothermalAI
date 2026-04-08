# Inventory DOE GDBs under 1303 and export rasters to GeoTIFF.
# Uses `conda run` so GDAL_DATA / PROJ_LIB are set correctly on Windows.
#
# If -DoeGdbRoot is omitted: prefers %USERPROFILE%\GIS Final Project (outside OneDrive Desktop).
# Desktop is often redirected to OneDrive on school accounts; only used as fallback if home path missing.
param(
    [string]$DoeGdbRoot = "",
    [string]$OutDir = ""
)
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$HomeGdb = Join-Path $env:USERPROFILE "GIS Final Project\1303\DOE_GDB"
$DesktopGdb = Join-Path $env:USERPROFILE "Desktop\GIS Final Project\1303\DOE_GDB"

if (-not $DoeGdbRoot) {
    if (Test-Path $HomeGdb) {
        $DoeGdbRoot = $HomeGdb
        Write-Host "Using profile path: $DoeGdbRoot"
    }
    elseif (Test-Path $DesktopGdb) {
        $DoeGdbRoot = $DesktopGdb
        Write-Host "Using Desktop copy: $DoeGdbRoot"
    }
    else {
        Write-Error @"
No DOE_GDB folder found. Expected (same 1303\DOE_GDB layout):
  $HomeGdb   <- primary (e.g. C:\Users\gmalo\GIS Final Project\1303\DOE_GDB)
  $DesktopGdb   <- fallback if Desktop is local, not OneDrive-only
Or pass: -DoeGdbRoot 'C:\path\to\...\1303\DOE_GDB'
"@
    }
}

if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "exports" }
$Inv = Join-Path $OutDir "inventory_1303_full.json"
$Tif = Join-Path $OutDir "geotiff_1303"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Conda = Join-Path $env:USERPROFILE "anaconda3\Scripts\conda.exe"
if (-not (Test-Path $Conda)) { $Conda = Join-Path $env:USERPROFILE "miniconda3\Scripts\conda.exe" }
if (-not (Test-Path $Conda)) {
    Write-Error "conda.exe not found. Install Anaconda/Miniconda or edit path in this script."
}

$ArgsInv = @(
    "run", "-n", "geothermal-gis", "python",
    (Join-Path $RepoRoot "scripts\inventory_gdbs.py"),
    "--root", $DoeGdbRoot,
    "-o", $Inv
)
& $Conda @ArgsInv
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ArgsExp = @(
    "run", "-n", "geothermal-gis", "python",
    (Join-Path $RepoRoot "scripts\export_gdb_rasters_to_geotiff.py"),
    "--inventory", $Inv,
    "--out-dir", $Tif
)
& $Conda @ArgsExp
exit $LASTEXITCODE
