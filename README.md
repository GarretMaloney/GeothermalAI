# GeothermalAI

GIS programming final project. I started out trying to replicate the Moraga et al. (2022) Geothermal AI work on Brady and Desert Peak. The data was in the hundreds of gigabytes, so running everything locally wasn’t really an option. I also tried some Salton Sea runs later as an extra site — that wasn’t part of the paper.

What I ended up building is a Colab wrapper that keeps the data in Google Cloud Storage, pulls the code from this GitHub repo, runs the original DOE 1307 scripts on a GPU runtime, and saves the outputs. Once that was working, the actual Moraga replication was mostly just configuring runs and checking metrics. The wrapper is the real project.

**Paper:** Moraga, J., Duzgun, H.S., Cavur, M., Soydan, H., *The Geothermal Artificial Intelligence for geothermal exploration*, *Renewable Energy* 192 (2022) 134–149. [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113)

---

## The Moraga pipeline

The paper’s full method is bigger than just the neural net. They pull remote-sensing / geospatial indicators (temperature, faults, mineral markers, deformation), run ML on those layers, use SOM clustering to auto-label geothermal vs non-geothermal, then train an Inception-style CNN on 19×19×3 tiles for 100 epochs with rotation/mirror augmentation. Brady has clear surface manifestations; Desert Peak is a blind site. Same-site test accuracy in the paper is about 92–95%; cross-site (train one, test the other on all points) is about 72–76%.

What I actually ran in the cloud is the DOE 1307 side of that — the scripts that take a prepared multi-band stack, cut tiles, train/validate, and map:

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

Those scripts live in [`Git_1307/`](Git_1307/). I didn’t rewrite the model — I wrapped how it gets run. My fidelity runs used **5** input channels instead of the paper’s **3**, so the numbers below are close comparisons, not an exact match.

---

## The wrapper

Main notebook: [`colab/colab_1307_git_gcs.ipynb`](colab/colab_1307_git_gcs.ipynb)

Code comes from GitHub. Data stays in GCS. Colab is just the machine that runs the job.

```text
GitHub (code)  ──clone/pull──►  Colab GPU
GCS (data)     ──gsutil──────►  Colab GPU
GCS (outputs)  ◄──sync────────  run folders / metrics
```

What it handles:

1. Auth and config (project, bucket, git branch, run name)
2. Clone / pull this repo
3. Pull the data the run needs from GCS
4. Call `create_doe_dataset.py`, `doe_geoai.py`, or `doe_ann_map.py`
5. Write `run_config.json`, metrics, and plots for that run
6. Sync outputs back to GCS when you’re done

Lightweight copies of the metrics and plots are in [`artifacts/1307/`](artifacts/1307/). Models and the big datasets stay in the bucket. More detail on the cloud setup: [`colab/README.md`](colab/README.md).

---

## Results

My main Brady / Desert Peak runs: 19×19 tiles, 5 channels, 100 epochs, 120k held-out tiles. Paper Table 2/3 used 19×19×3 and, for cross-site, every point in the test site. Numbers and JSON: [`cross_site_prediction_metrics.json`](colab/presentation_assets/cross_site_prediction_metrics.json), [`geoai_run_summary.csv`](artifacts/1307/geoai_run_summary.csv).

### Same-site (paper Table 2 vs my train runs)

| Site | Paper (Table 2) | This project (`train_*_19x5d_100ep`) |
|------|-----------------|-------------------------------------|
| Brady | **95.5%** | **97.8%** |
| Desert Peak | **92.3%** | **98.6%** |

### Cross-site (paper Table 3 vs my validate runs)

| Direction | Paper | This project | Macro F1 |
|-----------|-------|--------------|----------|
| Brady → Desert Peak | **72.4%** | **72.2%** | 70.5% |
| Desert Peak → Brady | **76.3%** | **72.6%** | 71.4% |

Brady → Desert Peak basically matched the paper’s headline number. Desert Peak → Brady came in lower, with a different precision/recall tradeoff — more detail in [`cross_site_prediction_rasters.md`](colab/presentation_assets/cross_site_prediction_rasters.md).

Salton Sea train/eval and transfer runs are under `artifacts/1307/metrics_*salton*`. Those were exploratory; Brady ↔ Desert Peak was the main check against the paper.

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

---

## What’s in the repo

| Path | What it is |
|------|------------|
| [`colab/`](colab/) | The wrapper notebook, cloud notes, presentation assets |
| [`Git_1307/`](Git_1307/) | Original DOE / Moraga scripts the wrapper calls |
| [`artifacts/1307/`](artifacts/1307/) | Metrics, run configs, plots from the cloud runs |
| [`scripts/`](scripts/) | Helpers for inventory, export, and GCS upload |
| [`exports/`](exports/) | Inventory snapshots |
