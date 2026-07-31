# GeothermalAI

**GIS programming final project → cloud pipeline engineering portfolio piece.**

I set out to replicate the Moraga et al. (2022) Geothermal AI workflow on DOE GDR data (Brady, Desert Peak, Salton Sea). The real hangup was **data volume and packaging**: the archives that actually held the model-ready inputs were on the order of **hundreds of gigabytes**. The smaller geodatabases I could keep locally did **not** contain the layers needed to rebuild the feature stacks / rasters the 1307 scripts expect — so “just work from the laptop GDB” was not a viable path.

The project pivoted. Instead of reimplementing the science model or trying to host hundreds of GB on a student machine, I built a **cloud orchestration wrapper** that keeps bulky inputs in Google Cloud Storage, pulls code from GitHub, runs the original DOE **1307** scripts on a Colab GPU, and syncs reproducible run artifacts back out. Once that path worked, the Moraga replication itself was mostly configuration and evaluation — the engineering product is the wrapper.

| | |
|---|---|
| **Course context** | GIS programming final project |
| **Original goal** | Replicate Moraga et al. Geothermal AI (train / cross-site validate / map) |
| **Constraint** | Hundreds-of-GB source archives; smaller local GDBs lacked the raster inputs |
| **Deliverable** | Colab + GitHub + GCS pipeline that runs the DOE scripts end-to-end |
| **Proof** | Cross-site metrics near the paper’s Brady→Desert Peak headline (~72%) |

**Paper:** Moraga, J., Duzgun, H.S., Cavur, M., *et al.*, *The Geothermal Artificial Intelligence for geothermal exploration*, *Renewable Energy* 192 (2022) 134–149. [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113)

---

## What I built (the wrapper)

The main artifact is [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb): an orchestration notebook, **not** a rewrite of the CNN.

**Design choices employers care about:**

- **Separation of concerns** — code lives in GitHub (`Git_1307/`); hundred‑GB source data and derived tile archives live in GCS; ephemeral Colab VMs only stage what a given run needs
- **Reproducible runs** — each execution writes `run_config.json` (paths, channels, epochs, Git commit, GCS URIs) plus metrics and plots
- **Vendor scripts unchanged** — wrap `create_doe_dataset.py`, `doe_geoai.py`, and `doe_ann_map.py` rather than forking the science into notebook cells
- **Failure mode → architecture** — “the real inputs don’t fit on this machine / aren’t in the small GDB” became a deliberate Git-for-code + cloud-for-data layout

```text
┌─────────────────┐     clone / pull      ┌──────────────────┐
│  GitHub (code)  │ ───────────────────►  │  Colab GPU VM    │
└─────────────────┘                       │  /content/...    │
┌─────────────────┐     gsutil rsync      │                  │
│  GCS (data)     │ ───────────────────►  │  run 1307 scripts│
│  .gri, .tar.gz  │ ◄───────────────────  │  write run dirs  │
└─────────────────┘     sync outputs      └──────────────────┘
```

| Step | What the wrapper does | Artifacts |
|------|------------------------|-----------|
| Auth + config | GCP project, bucket, Git URL/branch | `run_config.json` |
| Code | `git clone` / `pull` → `/content/GeothermalAI` | `Git_1307/*.py` |
| Data | `gsutil rsync` stacks / datasets | `/content/doe-data/...` |
| Build tiles | invoke `create_doe_dataset.py` | `.npy` tiles; optional `.tar.gz` on GCS |
| Train / validate | invoke `doe_geoai.py` | `.h5`, metrics JSON, plots, reports |
| Map (optional) | invoke `doe_ann_map.py` | prediction `.gri` / `.npy` |
| Persist | copy run folder off the VM | `gs://…/outputs/1307/<run_name>/` |

Committed lightweight outputs (metrics, configs, plots — not multi‑GB weights/datasets): [`artifacts/1307/`](artifacts/1307/).  
Setup notes: [`colab/README.md`](colab/README.md). Presentation draft: [`colab/presentation_1307_slides.md`](colab/presentation_1307_slides.md).

---

## What the wrapper runs (Moraga / DOE 1307)

The published workflow is supervised **patch classification**: stack aligned geoscience layers, sample 19×19 neighborhoods, train a CNN for geothermal vs non-geothermal, then map over the full site.

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

| DOE GDR | Role |
|---------|------|
| **1303** | Site geodatabases (Brady, Desert Peak, Salton Sea) |
| **1304–1306** | Per-site repository labels |
| **1307** | Pipeline programs (kept here under [`Git_1307/`](Git_1307/)) |

Once the cloud path was stable, replication was mostly choosing channels/epochs, launching named runs, and comparing metrics — not rebuilding the model from scratch.

---

## Results (evidence the pipeline works)

Fidelity settings: **19×19** kernels, **5** channels, **100** epochs, **120 000** held-out tiles. The paper’s Tables 2–3 describe a **3**-channel setup and full-site tests; numbers are comparable in spirit. Raw JSON: [`cross_site_prediction_metrics.json`](colab/presentation_assets/cross_site_prediction_metrics.json); full CSV: [`geoai_run_summary.csv`](artifacts/1307/geoai_run_summary.csv).

### Same-site training

| Run | Accuracy | Macro F1 |
|-----|----------|----------|
| Brady `train_brady_19x5d_100ep` | **97.8%** | 97.8% |
| Desert Peak `train_desertpeak_19x5d_100ep` | **98.6%** | 98.6% |

Paper Table 2 (context): Brady **95.5%**, Desert Peak **92.3%**.

### Cross-site validation vs paper (Table 3)

| Direction | Paper | This pipeline (19×5d, 100 ep) | Macro F1 |
|-----------|-------|-------------------------------|----------|
| Brady → Desert Peak | **72.4%** | **72.2%** | 70.5% |
| Desert Peak → Brady | **76.3%** | **72.6%** | 71.4% |

Brady→Desert Peak lands on the published headline. Desert Peak→Brady is lower accuracy with a different precision–recall tradeoff ([detail](colab/presentation_assets/cross_site_prediction_rasters.md)).

I also ran Salton Sea train/eval and Brady/Desert Peak→Salton transfer (see `artifacts/1307/metrics_*salton*`). Those were exploratory extension runs; stack QC and cross-province transfer are weaker than Brady↔Desert Peak, which remained the fidelity focus.

### Input stack (Brady)

![Brady stack layers](colab/presentation_assets/brady_stack_layers.png)

### Training curves

Brady 19×5d, 100 epochs:

![Brady training plot](artifacts/1307/train_brady_19x5d_100ep/doe_geoai_training_plot.png)

Desert Peak 19×5d, 100 epochs:

![Desert Peak training plot](artifacts/1307/train_desertpeak_19x5d_100ep/doe_geoai_training_plot.png)

### Cross-site confusion matrices

Brady model → Desert Peak tiles (**72.2%**):

![Brady on Desert Peak confusion matrix](artifacts/1307/metrics_brady_on_desertpeak_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

Desert Peak model → Brady tiles (**72.6%**):

![Desert Peak on Brady confusion matrix](artifacts/1307/metrics_desertpeak_on_brady_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

### Spatial prediction maps

Brady-trained model on the Desert Peak stack:

![Brady model → Desert Peak prediction](colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png)

Desert Peak–trained model on the Brady stack:

![Desert Peak model → Brady prediction](colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png)

---

## Skills demonstrated

- Cloud data + compute orchestration (GCS, Colab GPU, `gsutil`)
- Reproducible ML/GIS experiment tracking (`run_config.json`, metrics JSON, summary CSV)
- Wrapping legacy scientific code without rewriting it
- Git-based delivery of training code into ephemeral environments
- Cross-site evaluation and comparison to a published baseline
- Designing around real geospatial data constraints (hundred‑GB archives, incomplete local subsets)

---

## Repository layout

| Path | Contents |
|------|----------|
| [`colab/`](colab/) | **Primary deliverable** — Colab wrapper, GCS helpers, presentation assets |
| [`Git_1307/`](Git_1307/) | Upstream Moraga / DOE scripts invoked by the wrapper |
| [`artifacts/1307/`](artifacts/1307/) | Committed metrics, configs, reports, plots from cloud runs |
| [`scripts/`](scripts/) | Local GDB inventory, GeoTIFF export, GCS upload helpers |
| [`exports/`](exports/) | Committed GDB inventory snapshots |

---

## Local environment (optional)

Early work used a local conda-forge GDAL env for inventory / export before the cloud pivot:

```powershell
conda create -n geothermal-gis -c conda-forge python=3.11 gdal fiona rasterio numpy -y --solver=libmamba
# or: scripts/setup_conda_env.ps1
```

```powershell
$GDB = "C:/Users/gmalo/GIS Final Project/1303/DOE_GDB"
conda run -n geothermal-gis python scripts/inventory_gdbs.py --root $GDB -o exports/inventory_1303_full.json
conda run -n geothermal-gis python scripts/export_gdb_rasters_to_geotiff.py --inventory exports/inventory_1303_full.json --out-dir exports/geotiff_1303
```

Local inventory/export helped explore what was on disk, but the smaller GDBs alone were not enough to rebuild the Moraga stacks — the large archives and cloud staging were required. See [`colab/README.md`](colab/README.md) and [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb).
