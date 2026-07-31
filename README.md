# GeothermalAI

Replication of the **Moraga et al. (2022)** Geothermal AI workflow for binary geothermal prospectivity classification, run end-to-end in the cloud with a Colab orchestration wrapper around the DOE GDR **1307** scripts.

**Paper:** Moraga, J., Duzgun, H.S., Cavur, M., *et al.*, *The Geothermal Artificial Intelligence for geothermal exploration*, *Renewable Energy* 192 (2022) 134–149. [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113)

**Sites:** Brady Hot Springs · Desert Peak · Salton Sea (extension)

---

## The Moraga pipeline

The published workflow treats geothermal exploration as a **supervised patch classification** problem. Aligned geoscience / remote-sensing layers are stacked into a multi-band raster; a CNN learns to label each location as geothermal vs non-geothermal from a fixed-size neighborhood.

```text
SOM / feature stack (.gri)
        │
        ▼
  create_doe_dataset.py     →  random 19×19 tiles (.npy) + labels
        │
        ▼
  doe_geoai.py              →  train CNN (.h5) or validate (-v)
        │
        ▼
  doe_ann_map.py            →  full-site prediction raster
```

| Stage | Script (`Git_1307/`) | Role |
|-------|----------------------|------|
| **1. Stack** | Site geodatabases + SOM preprocessing | Band 1 = label mask; bands 2+ = features (mineral markers, LST, faults, deformation, …) |
| **2. Sample** | `create_doe_dataset.py` | Draw balanced tiles (kernel **19×19**, **3** or **5** channels) |
| **3. Train / eval** | `doe_geoai.py` | CNN with optional augmentation (`-a`); validate-only with `-v` |
| **4. Map** | `doe_ann_map.py` | Slide the trained model across the full stack for a spatial prediction |

Those scripts are the original DOE / Moraga **1307** programs (Python, plus R/shell helpers). This repo keeps them under [`Git_1307/`](Git_1307/) and focuses engineering effort on making them reproducible in the cloud.

### DOE GDR submissions

| Submission | Role |
|------------|------|
| **1303** | Geodatabases for Brady, Desert Peak, and Salton Sea |
| **1304 / 1305 / 1306** | Per-site repository labels |
| **1307** | Programs and code for the Geothermal AI pipeline |

---

## Cloud wrapper (Colab + GitHub + GCS)

Windows GDAL often cannot open the DOE `.gdb` rasters (permission / driver issues). The practical path is:

1. Upload site data and SOM stacks to **Google Cloud Storage**
2. Clone this repo in **Google Colab** (GPU)
3. Run the 1307 scripts through a notebook that handles auth, paths, deps, and artifact sync

The main runner is [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb). It is an **orchestration wrapper**, not a reimplementation of the model: training code always comes from GitHub (`Git_1307/`); large rasters and tile archives live in GCS.

```text
┌─────────────────┐     clone / pull      ┌──────────────────┐
│  GitHub (code)  │ ───────────────────►  │  Colab GPU VM    │
└─────────────────┘                       │  /content/...    │
┌─────────────────┐     gsutil rsync      │                  │
│  GCS (data)     │ ───────────────────►  │  run §7 scripts  │
│  .gri, .tar.gz  │ ◄───────────────────  │  write run dirs  │
└─────────────────┘     sync outputs      └──────────────────┘
```

What the notebook automates:

| Step | What happens | Artifacts |
|------|----------------|-----------|
| Auth + config | GCP project, bucket, Git URL/branch | `run_config.json` per run |
| Code | `git clone` / `pull` → `/content/GeothermalAI` | `Git_1307/*.py` |
| Data | `gsutil rsync` of stacks / datasets | `/content/doe-data/...` |
| Build tiles | `create_doe_dataset.py` | `.npy` tiles; optional `.tar.gz` to GCS |
| Train / validate | `doe_geoai.py` | `.h5`, metrics JSON, plots, reports |
| Map (optional) | `doe_ann_map.py` | prediction `.gri` / `.npy` |
| Persist | copy run folder to GCS | `gs://…/outputs/1307/<run_name>/` |

Lightweight metrics and plots from those runs are committed here under [`artifacts/1307/`](artifacts/1307/). Models (`.h5`) and full tile archives stay on GCS (~3 GiB of datasets). Details and upload helpers: [`colab/README.md`](colab/README.md).

**Presentation materials:** [`colab/presentation_1307_slides.md`](colab/presentation_1307_slides.md) and assets in [`colab/presentation_assets/`](colab/presentation_assets/).

---

## Results

Headline settings for the fidelity runs below: **19×19** kernels, **5** feature channels, **100** epochs, **120 000** held-out tiles per validation. Paper Table 2/3 used a **3**-channel description and full-site independent tests; numbers are comparable in spirit, not identical protocols. Raw JSON: [`colab/presentation_assets/cross_site_prediction_metrics.json`](colab/presentation_assets/cross_site_prediction_metrics.json) and per-run files under [`artifacts/1307/`](artifacts/1307/).

### Same-site training (this replication)

| Run | Accuracy | Macro F1 |
|-----|----------|----------|
| Brady train `train_brady_19x5d_100ep` | **97.8%** | 97.8% |
| Desert Peak train `train_desertpeak_19x5d_100ep` | **98.6%** | 98.6% |

Paper Table 2 (same-site, for context): Brady **95.5%**, Desert Peak **92.3%**.

### Cross-site validation vs paper (Table 3)

| Direction | Paper accuracy | This repo (19×5d, 100 ep) | Macro F1 |
|-----------|----------------|---------------------------|----------|
| Brady → Desert Peak | **72.4%** | **72.2%** | 70.5% |
| Desert Peak → Brady | **76.3%** | **72.6%** | 71.4% |

Brady→Desert Peak matches the published headline closely. Desert Peak→Brady is lower accuracy here with a different precision–recall tradeoff (see the detailed table in [`cross_site_prediction_rasters.md`](colab/presentation_assets/cross_site_prediction_rasters.md)).

Full run table: [`artifacts/1307/geoai_run_summary.csv`](artifacts/1307/geoai_run_summary.csv).

### Input stack (Brady)

Multi-band feature stack used before tiling — band layout for the Brady site:

![Brady stack layers](colab/presentation_assets/brady_stack_layers.png)

### Training curves

Brady 19×5d, 100 epochs:

![Brady training plot](artifacts/1307/train_brady_19x5d_100ep/doe_geoai_training_plot.png)

Desert Peak 19×5d, 100 epochs:

![Desert Peak training plot](artifacts/1307/train_desertpeak_19x5d_100ep/doe_geoai_training_plot.png)

### Cross-site confusion matrices (tile validation)

Brady model on Desert Peak tiles (**72.2%**):

![Brady on Desert Peak confusion matrix](artifacts/1307/metrics_brady_on_desertpeak_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

Desert Peak model on Brady tiles (**72.6%**):

![Desert Peak on Brady confusion matrix](artifacts/1307/metrics_desertpeak_on_brady_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

### Spatial prediction maps

Brady-trained model applied across the Desert Peak stack:

![Brady model → Desert Peak prediction](colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png)

Desert Peak–trained model applied across the Brady stack:

![Desert Peak model → Brady prediction](colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png)

---

## Repository layout

| Path | Contents |
|------|----------|
| [`Git_1307/`](Git_1307/) | Moraga / DOE Geothermal AI scripts (`doe_geoai.py`, `create_doe_dataset.py`, `doe_ann_map.py`, …) |
| [`colab/`](colab/) | Colab wrappers, GCS helpers, presentation assets |
| [`artifacts/1307/`](artifacts/1307/) | Committed metrics, `run_config.json`, classification reports, plots |
| [`scripts/`](scripts/) | Local GDB inventory / GeoTIFF export / GCS upload helpers |
| [`exports/`](exports/) | Committed GDB inventory snapshots |

---

## Local environment (optional)

For inventory / GeoTIFF export on Windows without Colab, use a conda-forge GDAL env (avoid mixing pip `gdal` with MSVC):

```powershell
conda create -n geothermal-gis -c conda-forge python=3.11 gdal fiona rasterio numpy -y --solver=libmamba
```

Or run [`scripts/setup_conda_env.ps1`](scripts/setup_conda_env.ps1). Point data at a local copy of `1303/DOE_GDB` (prefer a non-OneDrive path such as `%USERPROFILE%\GIS Final Project\1303\DOE_GDB`).

```powershell
$GDB = "C:/Users/gmalo/GIS Final Project/1303/DOE_GDB"
conda run -n geothermal-gis python scripts/inventory_gdbs.py --root $GDB -o exports/inventory_1303_full.json
conda run -n geothermal-gis python scripts/export_gdb_rasters_to_geotiff.py --inventory exports/inventory_1303_full.json --out-dir exports/geotiff_1303
```

One-shot: [`scripts/run_1303_pipeline.ps1`](scripts/run_1303_pipeline.ps1). Copy `config/data_sources.example.yaml` → `config/data_sources.yaml` for machine-specific paths (gitignored).

If local GDAL hits **Permission denied** on `.gdb` rasters, upload to GCS and use [`colab/colab_gdb_from_gcs.ipynb`](colab/colab_gdb_from_gcs.ipynb) instead — see [`colab/README.md`](colab/README.md).
