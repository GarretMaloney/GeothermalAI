# Geothermal AI — 10-minute presentation (draft)

*Edit names, dates, and figures. Same story as the “Presentation” cells in `colab_1307_git_gcs.ipynb` — this file is for reading/review only.*

---

## Slide 1 — Title

# Geothermal prospectivity with deep learning

**~10 minutes · GIS / remote sensing capstone**

This project’s Colab notebook is an **orchestration wrapper**: it pulls code from GitHub, stages rasters and tile datasets from Google Cloud Storage, applies small Colab compatibility patches, and runs the **1307 GeoAI scripts** — rather than embedding the full model implementation inline.

---

## Slide 2 — Reference study and motivation

- **Paper:** Moraga *et al.*, *Remote Sensing of Environment* (2022) — DOI: `10.1016/j.rse.2022.113237` (PDF: `1-s2.0-S096014812200581X-main`).
- **Core idea:** classify geothermal *prospectivity* pixels from stacked geoscience and remote-sensing layers using a CNN on fixed-size patches.
- **Replication focus:** **Brady** and **Desert Peak** cross-training vs published cross-site accuracy.
- **Extension:** **Salton Sea** as out-of-sample province — meaningful only after RS stack QC matches Brady/DP quality.

**Add a figure:** study area, workflow, or results from the PDF.

<!--
![Paper figure](figures/paper_fig_1.png)
-->

---

## Slide 3 — Geodatabase design (GIS backbone)

- **Doc:** `Geodatabase Design.docx`
- **Talking points:**
  - Consistent **per-site** structure (Brady / Desert Peak / Salton Sea GDBs).
  - **SOM grids** align layers before stacking into `*_som_output.gri`.
  - Vectors (faults, labels) vs model-ready rasters.

**Add a figure:** schema, folder tree, or relationships from the Word doc.

<!--
![GDB design](figures/gdb_schema.png)
-->

---

## Slide 4 — Remote sensing and geophysics stack

- **Inputs:** multi-band `*.gri` — band 1 = **label**, bands 2+ = **features**.
- **Paper-style settings:** **19×19** kernels, **100 epochs** for fidelity runs, **5** feature channels for full stack.
- **QC:** `scripts/visualize_site_stacks.py` for per-band figures before training.

**Add figures** (e.g. after Colab):

<!--
![Brady stack](stack_layer_figures/brady_stack_layers.png)
![Desert Peak stack](stack_layer_figures/desert_peak_stack_layers.png)
-->

*In Colab, paths are often `/content/stack_layer_figures/...`.*

---

## Slide 5 — Model architecture (ANN / CNN)

- Convolutional layers → local spatial patterns; dense head → **binary** geothermal vs non-geothermal.
- Match wording to the **network schematic** in the paper.

**Add a figure:** ANN/CNN diagram from Moraga *et al.*

<!--
![Network diagram](figures/moraga_ann_diagram.png)
-->

---

## Slide 6 — What the notebook automates

| Step | Role | Artifact |
|------|------|----------|
| 1 | Stage `.gri` and deps | GCS → `/content/...` |
| 2 | Build tiles | `create_doe_dataset.py` → `.npy` + optional `.tar.gz` |
| 3 | Train / validate | `doe_geoai.py` → `.h5`, `.l`, curves |
| 4 | Full raster (optional) | `doe_ann_map.py` → prediction `.gri` / `.npy` |
| 5 | Persist | Sync to `gs://.../outputs/1307/...` |

**Takeaway:** one place for auth, paths, patches, `run_config.json`.

---

## Slide 7 — Methods (~90 s)

1. **Preprocess:** aligned stack; label raster encodes occurrences.
2. **Sample:** random patch centers; respect masks.
3. **Augment:** rotations / mirrors (paper-style).
4. **Evaluate:** test tiles — accuracy, P/R/F1, confusion matrix, ROC/AUC as applicable.
5. **Compare:** Brady→Desert Peak and **reverse** vs Moraga *et al.*

**Optional figure:** augment examples or data split sketch.

---

## Slide 8 — Results vs paper

- One **headline number** beats a table during a 10-minute talk.
- Example: Brady → Desert Peak ~**72%**, consistent with the paper; reverse direction same ballpark with caveats.

**Add a figure:** training curves, confusion matrix, or row from `geoai_run_summary` / Excel.

Use `scripts/export_geoai_run_summary.py` for a single CSV/XLSX across runs.

---

## Slide 9 — Spatial prediction outputs

- `doe_ann_map.py` shows **where** the model is confident.
- Store under e.g. `gs://.../outputs/prediction-rasters/<run_name>/`.

**Add a figure:** basemap + semi-transparent prediction.

<!--
![Prediction overlay](figures/prediction_overlay.png)
-->

---

## Slide 10 — Limitations and next steps

- **Salton:** rebuild/normalize layers if stack QC fails.
- **Next:** joint Brady + Desert Peak → test Salton (extension beyond paper).
- **Caveat:** labels and harmonization drive cross-site metrics.

**Closing (edit):** Reproducible infrastructure in the notebook; science in data quality and evaluation.

---

## Slide 11 — Images cheat sheet (Colab)

1. Export PNG from PDF/Word or QGIS/matplotlib.
2. Upload in Colab **Files** or use `/content/figures/`.
3. In a notebook markdown cell: `![caption](/content/figures/name.png)`
4. **Slideshow:** View → Slideshow; each markdown cell can be one slide.

---

## Appendix — Backup notes

_Presenter notes, links (DOI, GitHub, PR), or extra slides._
