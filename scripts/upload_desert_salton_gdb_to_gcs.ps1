# Upload Desert Peak + Salton Sea folders from Downloads to GCS (same style as upload_bradygdb_gsutil.cmd).
# Uses: gsutil -m rsync -r  (incremental; safe to re-run).
# Progress: live gsutil + Google Cloud copy lines in the console; each job is also in exports\.
# Prerequisites: gcloud auth (application-default) login, project set, bucket access
#
# Usage:  .\scripts\upload_desert_salton_gdb_to_gcs.ps1

$ErrorActionPreference = "Stop"

$Bucket   = "gis-final-project"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Exports  = Join-Path $RepoRoot "exports"
if (-not (Test-Path $Exports)) { New-Item -ItemType Directory -Path $Exports -Force | Out-Null }

$Gsutil = Join-Path $env:LOCALAPPDATA "Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
if (-not (Test-Path -LiteralPath $Gsutil)) {
  $Gsutil = "${env:ProgramFiles(x86)}\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd"
}
if (-not (Test-Path -LiteralPath $Gsutil)) {
  Write-Error "gsutil.cmd not found. Install Google Cloud SDK."
  exit 1
}

# Edit if your local paths change
$Jobs = @(
  @{
    Name   = "DesertPeakGDB"
    Source = "C:\Users\gmalo\Downloads\DesertPeakGDB"
    Dest   = "gs://$Bucket/GIS Final Project/DesertPeakGDB"
  }
  @{
    Name   = "SaltonSeaGDB"
    Source = "C:\Users\gmalo\Downloads\SaltonSeaGDB"
    Dest   = "gs://$Bucket/GIS Final Project/SaltonSeaGDB"
  }
  @{
    Name   = "DesertPeak_geodatabase"
    Source = "C:\Users\gmalo\Downloads\DesertPeak_geodatabase"
    Dest   = "gs://$Bucket/GIS Final Project/DesertPeak_geodatabase"
  }
  @{
    Name   = "SaltonSea_geodatabase"
    Source = "C:\Users\gmalo\Downloads\SaltonSea_geodatabase"
    Dest   = "gs://$Bucket/GIS Final Project/SaltonSea_geodatabase"
  }
)

$Stamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$MainLog = Join-Path $Exports "gsutil_desert_salton_upload_$Stamp.log"
"====== $(Get-Date -Format o)  upload_desert_salton_gdb_to_gcs.ps1 =====" | Set-Content -Path $MainLog -Encoding utf8
"gsutil: $Gsutil" | Add-Content -Path $MainLog -Encoding utf8
"" | Add-Content -Path $MainLog -Encoding utf8

$jobIndex = 0
$failed   = 0

foreach ($j in $Jobs) {
  $jobIndex++
  if (-not (Test-Path -LiteralPath $j.Source)) {
    $msg = "SKIP Job $jobIndex/$($Jobs.Count) $($j.Name) - path missing: $($j.Source)"
    Write-Warning $msg
    $msg | Set-Content -Path (Join-Path $Exports "gsutil_skip_$($j.Name)_$Stamp.log") -Encoding utf8
    $failed++
    Add-Content -Path $MainLog -Value $msg
    continue
  }

  $JobLog = Join-Path $Exports "gsutil_upload_$($j.Name)_$Stamp.log"
  Write-Host ""
  Write-Host "================================================================" -ForegroundColor Cyan
  Write-Host " Job $jobIndex/$($Jobs.Count)  $($j.Name)" -ForegroundColor Cyan
  Write-Host " $(Get-Date -Format o)" -ForegroundColor DarkGray
  Write-Host " Source:  $($j.Source)" -ForegroundColor White
  Write-Host " Dest:    $($j.Dest)" -ForegroundColor White
  Write-Host "================================================================" -ForegroundColor Cyan

  "----- Job $jobIndex/$($Jobs.Count) $($j.Name) $(Get-Date -Format o) -----" | Add-Content -Path $MainLog -Encoding utf8
  "Source: $($j.Source) -> Dest: $($j.Dest)" | Add-Content -Path $MainLog -Encoding utf8

  # Call gsutil with NO pipeline so $LASTEXITCODE is really gsutil's. Log with Start-Transcript.
  $exitFromGsutil = 0
  try {
    Start-Transcript -Path $JobLog -Force | Out-Null
    & $Gsutil -m rsync -r $j.Source $j.Dest
    $exitFromGsutil = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
  } catch {
    $exitFromGsutil = 1
    $_ | ForEach-Object { $_.ToString() | Add-Content -Path $JobLog -Encoding utf8 }
  } finally {
    try { Stop-Transcript | Out-Null } catch { }
  }
  if (Test-Path -LiteralPath $JobLog) {
    Get-Content -Path $JobLog -ErrorAction SilentlyContinue | Add-Content -Path $MainLog -Encoding utf8
  }
  "Exit code: $exitFromGsutil" | Add-Content -Path $MainLog -Encoding utf8

  if ($exitFromGsutil -ne 0) {
    $failed++
    Write-Warning "Job $($j.Name) finished with non-zero exit: $exitFromGsutil (see $JobLog )"
  } else {
    Write-Host "OK: $($j.Name)   log: $JobLog" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Done. Non-zero jobs: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "Master log: $MainLog" -ForegroundColor White
"Total failures/skip: $failed" | Add-Content -Path $MainLog -Encoding utf8
if ($failed -gt 0) { exit 1 } else { exit 0 }
