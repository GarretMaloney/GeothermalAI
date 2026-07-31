# Cloud Orchestration for Moraga et al. Geothermal AI Replication

*Final project for a GIS programming course.*

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/GarretMaloney/GeothermalAI/blob/main/colab/colab_1307_git_gcs.ipynb)

This project replicates parts of the Moraga et al. (2022) Geothermal AI workflow for binary geothermal prospectivity classification at Brady Hot Springs and Desert Peak, Nevada, using DOE Geothermal Data Repository materials and the original 1307 training scripts. The engineering focus of the project became a Colab orchestration wrapper that stages large datasets from Google Cloud Storage, pulls code from GitHub, and runs those scripts on a GPU runtime.

**Paper:** Moraga, J., Duzgun, H.S., Cavur, M., Soydan, H., *The Geothermal Artificial Intelligence for geothermal exploration*, *Renewable Energy* 192 (2022) 134–149. [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113)

## Scope Development

Initially, the plan was to replicate the Moraga pipeline locally: prepare multi-band stacks, generate training tiles, train the CNN, and produce cross-site prediction maps for Brady and Desert Peak. During development, it became clear that local execution was not practical — the source data was in the hundreds of gigabytes, well beyond what could be stored and processed comfortably on a laptop.

The project shifted toward building a cloud wrapper around the existing DOE 1307 scripts rather than reimplementing the model. Once code lived in GitHub and data lived in GCS, replication reduced largely to configuring runs, launching jobs in Colab, and comparing metrics to the paper. Salton Sea train/eval and transfer runs were added later as an exploratory extension; that site is not part of the Moraga study.

## Methods

**Reference workflow.** Moraga et al. integrate remote sensing and geospatial indicators (temperature, faults, mineral markers, deformation), apply ML to extract patterns, use SOM clustering for automatic geothermal / non-geothermal labeling, then train an Inception-style CNN on 19×19×3 tiles for 100 epochs with rotation and mirror augmentation. Brady has clear surface manifestations; Desert Peak is a blind site. Published same-site test accuracy is about 92–95% (Table 2); cross-site accuracy, training on one site and testing on all points of the other, is about 72–76% (Table 3).

**What this project runs.** The cloud jobs invoke the DOE 1307 scripts on prepared multi-band stacks — tile generation, training/validation, and optional full-site mapping — without rewriting the network:

```text
feature stack (.gri)
        │
        ▼
  create_doe_dataset.py   →  19×19 tiles + labels
        │
        ▼
  doe_geoai.py            →  train (.h5) or validate (-v)
        │
        ▼
  doe_ann_map.py          →  full-site prediction map
```

Scripts are kept under [`Git_1307/`](Git_1307/). Fidelity runs used **5** input channels rather than the paper’s **3**, so comparisons to Tables 2–3 are close rather than exact.

**Cloud wrapper.** [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb) handles authentication and run configuration, clones or pulls this repository, syncs the data needed for a given job from GCS, calls the 1307 entry scripts, writes `run_config.json` plus metrics and plots, and syncs outputs back to the bucket. Code and data stay separated: GitHub for scripts, GCS for large inputs and full run artifacts. Lightweight metrics and figures are committed under [`artifacts/1307/`](artifacts/1307/). Setup notes: [`colab/README.md`](colab/README.md).

```text
GitHub (code)  ──clone/pull──►  Colab GPU
GCS (data)     ──gsutil──────►  Colab GPU
GCS (outputs)  ◄──sync────────  run folders / metrics
```

## Results

Main Brady / Desert Peak settings: 19×19 tiles, 5 channels, 100 epochs, 120,000 held-out tiles per validation. Paper Table 3 uses every point in the test site. Raw numbers: [`cross_site_prediction_metrics.json`](colab/presentation_assets/cross_site_prediction_metrics.json), [`geoai_run_summary.csv`](artifacts/1307/geoai_run_summary.csv).

**Same-site (paper Table 2 vs train runs):**

| Site | Paper (Table 2) | This project (`train_*_19x5d_100ep`) |
|------|-----------------|-------------------------------------|
| Brady | **95.5%** | **97.8%** |
| Desert Peak | **92.3%** | **98.6%** |

**Cross-site (paper Table 3 vs validate runs):**

| Direction | Paper | This project | Macro F1 |
|-----------|-------|--------------|----------|
| Brady → Desert Peak | **72.4%** | **72.2%** | 70.5% |
| Desert Peak → Brady | **76.3%** | **72.6%** | 71.4% |

Brady → Desert Peak closely matches the published headline accuracy. Desert Peak → Brady is lower here, with a different precision–recall tradeoff — see [`cross_site_prediction_rasters.md`](colab/presentation_assets/cross_site_prediction_rasters.md). Salton Sea results under `artifacts/1307/metrics_*salton*` are exploratory; Brady ↔ Desert Peak was the primary check against the paper.

**Important caveats:** channel count (5 vs 3), sampling (120k tiles vs full-site independent test), and stack construction all differ from the paper’s protocol. Same-site accuracies above paper Table 2 should be read with those differences in mind rather than as a strict improvement claim.

### Input stack (Brady)

![Brady stack layers](colab/presentation_assets/brady_stack_layers.png)

### Training curves

Brady, 19×5d, 100 epochs:

![Brady training plot](artifacts/1307/train_brady_19x5d_100ep/doe_geoai_training_plot.png)

Desert Peak, 19×5d, 100 epochs:

![Desert Peak training plot](artifacts/1307/train_desertpeak_19x5d_100ep/doe_geoai_training_plot.png)

### Cross-site confusion matrices

Brady model on Desert Peak tiles (72.2%):

![Brady on Desert Peak confusion matrix](artifacts/1307/metrics_brady_on_desertpeak_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

Desert Peak model on Brady tiles (72.6%):

![Desert Peak on Brady confusion matrix](artifacts/1307/metrics_desertpeak_on_brady_19x5d_100ep/doe_geoai_training_curves.csv.Non-geothemal.png)

### Prediction maps

Brady-trained model on Desert Peak:

![Brady model → Desert Peak prediction](colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png)

Desert Peak–trained model on Brady:

![Desert Peak model → Brady prediction](colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png)

## Repository

| Path | Contents |
|------|----------|
| [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb) | Main orchestration notebook |
| [`colab/`](colab/) | Cloud setup notes and presentation assets |
| [`Git_1307/`](Git_1307/) | DOE / Moraga scripts invoked by the wrapper |
| [`artifacts/1307/`](artifacts/1307/) | Metrics, run configs, and plots from cloud runs |
| [`scripts/`](scripts/) | Inventory, export, and GCS upload helpers |
| [`exports/`](exports/) | Inventory snapshots |
