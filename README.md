# GeothermalAI

GIS programming final project: replicate the **Moraga et al. (2022)** Geothermal AI training / evaluation workflow in Python, using DOE Geothermal Data Repository (GDR) materials and remotely sensed inputs (mineral markers, LST, faults, deformation, etc.).

## GDR layout (how your SSD fits together)

| Submission | Role |
|------------|------|
| **1303** | Appendices + **geodatabases for all three sites** (Brady, Desert Peak, Salton Sea) in one bundle — this is the main spatial data drop you already have. |
| **1304 / 1305 / 1306** | Repository **labels** used to identify or group content **per site** (you have these on disk alongside 1303). |
| **1307** | **Programs and code** for the Geothermal AI pipeline (Python/R/shell), not a fourth “site” dataset. |

Primary paper: Moraga, J., et al., *The Geothermal Artificial Intelligence for geothermal exploration*, *Renewable Energy*, 2022, [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113).

## `conda` not recognized in Command Prompt

Anaconda often does not add `conda` to **PATH** for plain `cmd.exe`. Use the full path:

```bat
"%USERPROFILE%\anaconda3\Scripts\conda.exe" run -n geothermal-gis python C:\Users\gmalo\GeothermalAI\scripts\inventory_gdbs.py --root "C:\Users\gmalo\GIS Final Project\1303\DOE_GDB" -o C:\Users\gmalo\GeothermalAI\exports\inventory_1303_full.json
```

Or run **`Anaconda Prompt`** / **"Anaconda PowerShell Prompt"** from the Start menu (conda is on PATH there).  
To fix PATH permanently: open **Anaconda Prompt**, run `conda init cmd.exe`, restart **cmd**.

**Shortcut:** from the repo, double‑click or run **`scripts\inventory_1303.cmd`** (uses `%USERPROFILE%\anaconda3\Scripts\conda.exe` automatically).

## Environment (Windows: conda-forge + libmamba)

Avoid mixing pip `gdal` with MSVC. Use a dedicated env:

```powershell
# Optional: faster solver (once)
conda install -n base conda-libmamba-solver -y --solver=classic

conda create -n geothermal-gis -c conda-forge python=3.11 gdal fiona rasterio numpy -y --solver=libmamba
```

Or run **`scripts/setup_conda_env.ps1`** (same as above).

**Run Python with GDAL via `conda run`** so `GDAL_DATA` / `PROJ_LIB` are correct:

**Where to put data (Windows):** If **Desktop** was moved under OneDrive, treat **`%USERPROFILE%\GIS Final Project`** as the main working copy (e.g. **`C:\Users\gmalo\GIS Final Project\1303\DOE_GDB`**). That avoids the `OneDrive - csulb\Desktop\...` tree.

`scripts/run_1303_pipeline.ps1` uses **`GIS Final Project\1303\DOE_GDB`** under your profile **first**; Desktop is only a fallback.

```powershell
$GDB = "C:/Users/gmalo/GIS Final Project/1303/DOE_GDB"
conda run -n geothermal-gis python scripts/inventory_gdbs.py --root $GDB -o exports/inventory_1303_full.json
conda run -n geothermal-gis python scripts/export_gdb_rasters_to_geotiff.py --inventory exports/inventory_1303_full.json --out-dir exports/geotiff_1303
```

One-shot: **`scripts/run_1303_pipeline.ps1`** (defaults to profile `GIS Final Project` path).

`scripts/bootstrap_gdal_env.py` also sets `GDAL_DATA` / `PROJ_LIB` from `sys.prefix` when you call the scripts with a plain `python.exe` from that env.

### If data lives under OneDrive

Prefer a path like **`C:\Users\gmalo\GIS Final Project`** for GDAL; if you must use a OneDrive folder, use **Always keep on this device** and expect occasional **Permission denied** until data is copied outside sync.

### If raster step says “Permission denied” on `.gdb`

Some external/USB drives or policies block GDAL’s second raster open. Copy the `DOE_GDB` folder to a local disk (e.g. `C:\data\DOE_GDB`) and point `--root` there, then re-run inventory + export.

## Config

Copy `config/data_sources.example.yaml` to `config/data_sources.yaml` and set paths to your SSD. `data_sources.yaml` is gitignored so machine-specific paths stay local.

## Scripts (all Python, no ArcGIS)

- **`scripts/inventory_gdbs.py`** — Every `.gdb`: **vector layers** (schemas, CRS) + **raster subdatasets** when GDAL can open them.
- **`scripts/export_gdb_rasters_to_geotiff.py`** — Export listed rasters to **GeoTIFF** (+ `export_manifest.json`).
- **`scripts/inspect_gdb_rasters.py`** — GDAL-only quick peek + band stats.

Committed snapshot of a full vector inventory: **`exports/inventory_1303_full.json`** (raster URIs may be empty if the run hit permission issues on the drive).

## Cloud path (when Windows GDAL says Permission denied)

Upload **`1303/DOE_GDB`** to **Google Cloud Storage**, then run **`colab/colab_gdb_from_gcs.ipynb`** in **Colab** (Linux GDAL). See **`colab/README.md`** and **`scripts/upload_doe_gdb_gsutil.cmd`** (edit bucket + run) or **`scripts/upload_doe_gdb_to_gcs.py`** with `requirements-gcs.txt`.

## Next steps toward Moraga et al.

1. Get **`raster_subdatasets`** populated (local copy of GDB if needed), then export GeoTIFFs and stack bands to match `create_doe_dataset.py` (mask in first channel).
2. Train / evaluate in Python (Colab or GPU), then sync artifacts to GCS when ready.
