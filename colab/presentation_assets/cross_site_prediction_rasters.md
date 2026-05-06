# Cross-site prediction rasters (Brady ↔ Desert Peak)

Tile-level CNN metrics from `doe_geoai.py` **validation** (`-v`): trained model from one site, **test tiles from the other** (19×19×**5** channels, 120k samples per run). **100 training epochs** per model (`*_19x5d_100ep` runs). Figures below match these evaluations.

**Paper reference (comparison tables):** Moraga, J., Duzgun, H.S., Cavur, M., *et al.*, *The Geothermal Artificial Intelligence for geothermal exploration*, **Renewable Energy** 192 (2022) 134–149. [doi:10.1016/j.renene.2022.04.113](https://doi.org/10.1016/j.renene.2022.04.113). Values below are transcribed from the paper’s **Table 2** (train/test on the same site) and **Table 3** (independent cross-site test, no training pixels from the evaluated site).

---

## Brady-trained model → Desert Peak tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png" width="1000" alt="Brady model predicted on Desert Peak raster">

## Desert Peak–trained model → Brady tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png" width="1000" alt="Desert Peak model predicted on Brady raster">

---

## Paper vs this replication (cross-site, Table 3)

Independent test: model trained at one site, evaluated on **all** points/tiles at the other site (paper Table 3). Class **0 = non-geothermal**, **1 = geothermal** (matches sklearn `classification_report` in our runs).

| Direction | Source | Accuracy | Non-geo precision | Non-geo recall | Geothermal precision | Geothermal recall |
|-----------|--------|----------|---------------------|----------------|----------------------|-------------------|
| Brady → Desert Peak | **Paper (Table 3)** | **72.4%** | 66% | 97% | 94% | 46% |
| Brady → Desert Peak | **This repo** (19×5, 100 ep) | **72.24%** | 65.1% | 96.1% | 92.5% | 48.3% |
| Desert Peak → Brady | **Paper (Table 3)** | **76.3%** | 72% | 79% | 81% | 74% |
| Desert Peak → Brady | **This repo** (19×5, 100 ep) | **72.64%** | 89.1% | 51.7% | 65.9% | 93.7% |

**Note:** Overall **accuracy** is directly comparable in spirit; **per-class precision/recall** can shift with a different sample tally (paper uses full-site grids; we use 120k labeled tiles), label harmonization, and **5-channel** stacks vs the paper’s **3-channel** 19×19 description. The Brady→Desert Peak row is very close to the published headline **72.4%**. The Desert Peak→Brady direction is **lower accuracy** here but with a different precision–recall tradeoff—worth discussing in a write-up rather than over-interpreting pointwise.

### Paper Table 2 — same-site performance (context)

| Model (trained & tested) | Accuracy | Non-geo P/R | Geothermal P/R |
|--------------------------|----------|-------------|----------------|
| Brady | **95.5%** | 95% / 96% | 96% / 95% |
| Desert Peak | **92.3%** | 91% / 94% | 94% / 91% |

---

## This replication — full tile validation summary

| Direction | Model (trained site) | Test tile set | Samples | Accuracy | Macro F1 | Weighted F1 | Macro precision | Macro recall |
|-----------|----------------------|---------------|---------|----------|-----------|-------------|-----------------|--------------|
| **Brady → Desert Peak** | Brady (`brady_19x5d`) | `desertpeak_samples_19x5d` | 120 000 | **72.24%** | **70.54%** | **70.55%** | 78.80% | 72.21% |
| **Desert Peak → Brady** | Desert Peak (`desertpeak_19x5d`) | `brady_samples_19x5d` | 120 000 | **72.64%** | **71.39%** | **71.38%** | 75.07% | 72.66% |

### Per-class F1 (same order as above)

| Direction | Class 0 F1 | Class 1 F1 |
|-----------|------------|------------|
| Brady → Desert Peak | 77.61% | 63.48% |
| Desert Peak → Brady | 65.40% | 77.37% |

### Confusion matrices (rows = true 0 / 1, cols = pred 0 / 1)

| Direction | TN | FP | FN | TP |
|-----------|----|----|----|----|
| Brady → Desert Peak | 57 734 | 2 339 | 30 975 | 28 952 |
| Desert Peak → Brady | 31 030 | 29 043 | 3 792 | 56 135 |

### Run settings (both)

- `kernel_pixels = 19`, `image_channels = 5`, `num_epochs = 100`, `batch_size = 32`, `validate_only = true`

Raw metrics snapshots are committed as `cross_site_prediction_metrics.json` in this folder.
