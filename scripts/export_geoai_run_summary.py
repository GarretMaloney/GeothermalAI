#!/usr/bin/env python3
"""
Export DOE GeoAI run metrics/config JSON files to a flat CSV.

Expected input layout:
  root/
    run_name/
      metrics.json
      run_config.json

This intentionally keeps derived settings and raw paths in the same table so
completed experiments can be traced back to the exact Colab command.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


FIELDNAMES = [
    "run_name",
    "created_utc",
    "gcs_run_uri",
    "entry_script",
    "validate_only",
    "accuracy",
    "macro_precision",
    "macro_recall",
    "macro_f1",
    "weighted_precision",
    "weighted_recall",
    "weighted_f1",
    "class0_precision",
    "class0_recall",
    "class0_f1",
    "class0_support",
    "class1_precision",
    "class1_recall",
    "class1_f1",
    "class1_support",
    "tn",
    "fp",
    "fn",
    "tp",
    "test_samples",
    "dataset_path",
    "model_file",
    "image_channels",
    "kernel_pixels",
    "num_epochs",
    "batch_size",
    "num_classes",
    "predicted_probability_shape",
    "doe_dataset_path",
    "gcs_dataset_archive",
    "doe_model_path",
    "doe_labelbin_path",
    "doe_channels",
    "doe_kernel_pixels",
    "doe_epochs",
    "doe_batch_size",
    "doe_gpus",
    "doe_extra_args",
    "sync_dataset_to_gcs",
    "git_branch",
    "git_commit",
    "command",
]


def get_nested(mapping: dict[str, Any], *keys: str) -> Any:
    value: Any = mapping
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def stringify(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, separators=(",", ":"))
    return str(value)


def row_for_run(run_dir: Path) -> dict[str, str]:
    metrics_path = run_dir / "metrics.json"
    config_path = run_dir / "run_config.json"
    metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
    config = json.loads(config_path.read_text(encoding="utf-8"))
    report = metrics.get("classification_report", {})
    cm = metrics.get("confusion_matrix") or []
    tn = fp = fn = tp = None
    if len(cm) >= 2 and len(cm[0]) >= 2 and len(cm[1]) >= 2:
        tn, fp = cm[0][0], cm[0][1]
        fn, tp = cm[1][0], cm[1][1]

    row: dict[str, Any] = {
        "run_name": run_dir.name,
        "created_utc": config.get("created_utc"),
        "gcs_run_uri": config.get("gcs_run_uri"),
        "entry_script": config.get("entry_script"),
        "validate_only": metrics.get("validate_only"),
        "accuracy": metrics.get("accuracy"),
        "macro_precision": get_nested(report, "macro avg", "precision"),
        "macro_recall": get_nested(report, "macro avg", "recall"),
        "macro_f1": get_nested(report, "macro avg", "f1-score"),
        "weighted_precision": get_nested(report, "weighted avg", "precision"),
        "weighted_recall": get_nested(report, "weighted avg", "recall"),
        "weighted_f1": get_nested(report, "weighted avg", "f1-score"),
        "class0_precision": get_nested(report, "0", "precision"),
        "class0_recall": get_nested(report, "0", "recall"),
        "class0_f1": get_nested(report, "0", "f1-score"),
        "class0_support": get_nested(report, "0", "support"),
        "class1_precision": get_nested(report, "1", "precision"),
        "class1_recall": get_nested(report, "1", "recall"),
        "class1_f1": get_nested(report, "1", "f1-score"),
        "class1_support": get_nested(report, "1", "support"),
        "tn": tn,
        "fp": fp,
        "fn": fn,
        "tp": tp,
        "test_samples": metrics.get("test_samples"),
        "dataset_path": metrics.get("dataset_path"),
        "model_file": metrics.get("model_file"),
        "image_channels": metrics.get("image_channels"),
        "kernel_pixels": metrics.get("kernel_pixels"),
        "num_epochs": metrics.get("num_epochs"),
        "batch_size": metrics.get("batch_size"),
        "num_classes": metrics.get("num_classes"),
        "predicted_probability_shape": metrics.get("predicted_probability_shape"),
        "doe_dataset_path": config.get("doe_dataset_path"),
        "gcs_dataset_archive": config.get("gcs_dataset_archive"),
        "doe_model_path": config.get("doe_model_path"),
        "doe_labelbin_path": config.get("doe_labelbin_path"),
        "doe_channels": config.get("doe_channels"),
        "doe_kernel_pixels": config.get("doe_kernel_pixels"),
        "doe_epochs": config.get("doe_epochs"),
        "doe_batch_size": config.get("doe_batch_size"),
        "doe_gpus": config.get("doe_gpus"),
        "doe_extra_args": config.get("doe_extra_args"),
        "sync_dataset_to_gcs": config.get("sync_dataset_to_gcs"),
        "git_branch": config.get("git_branch"),
        "git_commit": config.get("git_commit"),
        "command": config.get("command"),
    }
    return {key: stringify(row.get(key)) for key in FIELDNAMES}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input_root", type=Path, help="Folder containing one subfolder per run.")
    parser.add_argument("output_csv", type=Path, help="CSV file to write.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    run_dirs = sorted(
        path
        for path in args.input_root.iterdir()
        if (path / "metrics.json").is_file() and (path / "run_config.json").is_file()
    )
    if not run_dirs:
        raise SystemExit(f"No run metrics/config pairs found under {args.input_root}")

    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        writer.writeheader()
        for run_dir in run_dirs:
            writer.writerow(row_for_run(run_dir))
    print(f"Wrote {len(run_dirs)} rows to {args.output_csv}")


if __name__ == "__main__":
    main()
