# Cross-site prediction rasters (Brady ↔ Desert Peak)

Tile-level CNN metrics from `doe_geoai.py` **validation** (`-v`): trained model from one site, **test tiles from the other** (19×19×3 windows, 120k samples per run). Same runs as the spatial prediction maps below.

---

## Brady-trained model → Desert Peak tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png" width="1000" alt="Brady model predicted on Desert Peak raster">

## Desert Peak–trained model → Brady tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png" width="1000" alt="Desert Peak model predicted on Brady raster">

---

## Evaluation summary

| Direction | Model (trained site) | Test tile set | Samples | Accuracy | Macro F1 | Weighted F1 | Macro precision | Macro recall |
|-----------|----------------------|---------------|---------|----------|-----------|-------------|-----------------|--------------|
| **Brady → Desert Peak** | Brady | `desertpeak_samples_19x3d` | 120 000 | **71.92%** | **70.09%** | **70.10%** | 78.91% | 71.89% |
| **Desert Peak → Brady** | Desert Peak | `brady_samples_19x3d` | 120 000 | **74.45%** | **74.44%** | **74.39%** | 74.49% | 74.45% |

### Per-class F1 (same order as above)

| Direction | Class 0 F1 | Class 1 F1 |
|-----------|------------|------------|
| Brady → Desert Peak | 77.48% | 62.70% |
| Desert Peak → Brady | 74.97% | 73.90% |

### Confusion matrices (rows = true 0 / 1, cols = pred 0 / 1)

| Direction | TN | FP | FN | TP |
|-----------|----|----|----|----|
| Brady → Desert Peak | 57 972 | 2 101 | 31 601 | 28 326 |
| Desert Peak → Brady | 45 925 | 14 148 | 16 513 | 43 414 |

### Run settings (both)

- `kernel_pixels = 19`, `image_channels = 3`, `num_epochs = 25`, `batch_size = 32`, `validate_only = true`

Raw metrics snapshots are committed as `cross_site_prediction_metrics.json` in this folder.
