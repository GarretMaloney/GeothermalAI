# Cross-site prediction rasters (Brady ↔ Desert Peak)

Tile-level CNN metrics from `doe_geoai.py` **validation** (`-v`): trained model from one site, **test tiles from the other** (19×19×**5** channels, 120k samples per run). **100 training epochs** per model (`*_19x5d_100ep` runs). Figures below match these evaluations.

---

## Brady-trained model → Desert Peak tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_brady_model_to_desert_peak.png" width="1000" alt="Brady model predicted on Desert Peak raster">

## Desert Peak–trained model → Brady tiles

<img src="https://raw.githubusercontent.com/GarretMaloney/GeothermalAI/main/colab/presentation_assets/prediction-raster-figures_desert_peak_model_to_brady.png" width="1000" alt="Desert Peak model predicted on Brady raster">

---

## Evaluation summary

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
