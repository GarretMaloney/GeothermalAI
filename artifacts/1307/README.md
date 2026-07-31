# 1307 run artifacts (metrics / configs / plots)

Lightweight snapshots synced from
`gs://gis-final-project/GIS Final Project/outputs/1307/`
(models, label bins, and sample archives are **not** included — they remain on GCS).

## Layout

| Path | Contents |
|------|----------|
| `geoai_run_summary.csv` | One-row-per-run metrics table |
| `metrics_*/` | Validate-only (and some train) runs: `run_config.json`, `*.metrics.json`, classification report, confusion-matrix PNG |
| `train_*_19x5d_100ep/` | Brady / Desert Peak 19×5d 100-epoch train summaries + plots |
| `build_*_dataset_19x5d/` | Dataset-build `run_config.json` |
| `run_YYYYMMDD_*/` | Earlier exploratory runs (config ± plots) |

Typical files in a metrics folder:

- `run_config.json` — Colab/GCS settings for the run
- `doe_geoai_training_curves.csv.metrics.json` — accuracy, F1, confusion matrix
- `doe_geoai_training_curves.csv.classification_report.txt`
- `doe_geoai_training_curves.csv.Non-geothemal.png` — confusion-matrix figure
- `doe_geoai_training_plot.png` — present when the run wrote a training curve plot

## Still on GCS only

- `doe_geoai_model.h5` (~45 MiB each)
- `doe-datasets/*.tar.gz` (~3.2 GiB total)
- Prediction rasters under `.../outputs/prediction-rasters/`

Cross-site summary used in slides also lives at
`colab/presentation_assets/cross_site_prediction_metrics.json`.
