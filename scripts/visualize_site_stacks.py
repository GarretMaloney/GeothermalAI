#!/usr/bin/env python3
"""
Visualize DOE GeoAI multi-band site stacks.

The stack convention used by create_doe_dataset.py is:
  band 1 = geothermal ground-truth label
  bands 2..N = model input layers

Examples:
  python scripts/visualize_site_stacks.py ^
    --site Brady="C:/path/to/brady_som_output.gri" ^
    --site DesertPeak="C:/path/to/desert_som_output.gri" ^
    --site Salton="C:/path/to/salton_som_output.gri"

  python scripts/visualize_site_stacks.py ^
    --brady-stack "/content/.../brady_som_output.gri" ^
    --desert-peak-stack "/content/.../desert_som_output.gri" ^
    --salton-stack "/content/.../salton_som_output.gri" ^
    --output-dir "/content/stack_layer_figures"
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path
from typing import Iterable

import matplotlib.pyplot as plt
import numpy as np
import rasterio
from rasterio.enums import Resampling


DEFAULT_BAND_NAMES = [
    "Geothermal label",
    "Minerals",
    "Temperature",
    "Faults",
    "Subsidence",
    "Uplift",
]


def parse_site(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError(
            "--site must look like Name=/path/to/stack.gri"
        )
    name, path = value.split("=", 1)
    name = name.strip()
    path = path.strip()
    if not name or not path:
        raise argparse.ArgumentTypeError(
            "--site must include both a non-empty name and path"
        )
    return name, Path(path)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create PNG visualizations for each band in DOE GeoAI stack rasters."
    )
    parser.add_argument(
        "--site",
        action="append",
        type=parse_site,
        default=[],
        help="Site stack as Name=/path/to/stack.gri. Can be repeated.",
    )
    parser.add_argument("--brady-stack", type=Path, help="Path to brady_som_output.gri.")
    parser.add_argument(
        "--desert-peak-stack", type=Path, help="Path to desert_som_output.gri."
    )
    parser.add_argument("--salton-stack", type=Path, help="Path to salton_som_output.gri.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("stack_layer_figures"),
        help="Directory where PNG figures will be written.",
    )
    parser.add_argument(
        "--band-names",
        default=",".join(DEFAULT_BAND_NAMES),
        help="Comma-separated band labels. Defaults to the 6-band DOE stack convention.",
    )
    parser.add_argument(
        "--max-dim",
        type=int,
        default=1400,
        help="Maximum rendered width/height in pixels per band for faster plotting.",
    )
    parser.add_argument(
        "--percentile-low",
        type=float,
        default=2.0,
        help="Lower percentile for continuous layer display stretch.",
    )
    parser.add_argument(
        "--percentile-high",
        type=float,
        default=98.0,
        help="Upper percentile for continuous layer display stretch.",
    )
    parser.add_argument(
        "--dpi",
        type=int,
        default=180,
        help="Output figure DPI.",
    )
    return parser.parse_args()


def clean_name(value: str) -> str:
    return "".join(ch if ch.isalnum() or ch in ("-", "_") else "_" for ch in value)


def site_inputs(args: argparse.Namespace) -> list[tuple[str, Path]]:
    sites = list(args.site)
    if args.brady_stack:
        sites.append(("Brady", args.brady_stack))
    if args.desert_peak_stack:
        sites.append(("Desert Peak", args.desert_peak_stack))
    if args.salton_stack:
        sites.append(("Salton", args.salton_stack))
    return sites


def output_shape(width: int, height: int, max_dim: int) -> tuple[int, int]:
    if max(width, height) <= max_dim:
        return height, width
    scale = max_dim / float(max(width, height))
    return max(1, int(round(height * scale))), max(1, int(round(width * scale)))


def read_band_preview(src: rasterio.DatasetReader, band: int, max_dim: int) -> np.ndarray:
    out_height, out_width = output_shape(src.width, src.height, max_dim)
    arr = src.read(
        band,
        out_shape=(out_height, out_width),
        resampling=Resampling.nearest,
        masked=True,
    )
    return np.ma.asarray(arr)


def finite_values(arr: np.ndarray | np.ma.MaskedArray) -> np.ndarray:
    if np.ma.isMaskedArray(arr):
        values = arr.compressed()
    else:
        values = np.asarray(arr).ravel()
    values = values[np.isfinite(values)]
    return values


def is_discrete(values: np.ndarray) -> bool:
    if values.size == 0:
        return True
    unique = np.unique(values)
    if unique.size <= 12:
        return True
    return np.allclose(unique, np.round(unique))


def display_limits(
    values: np.ndarray,
    percentile_low: float,
    percentile_high: float,
) -> tuple[float | None, float | None]:
    if values.size == 0:
        return None, None
    unique = np.unique(values)
    if unique.size <= 2:
        return float(np.nanmin(values)), float(np.nanmax(values))
    low, high = np.nanpercentile(values, [percentile_low, percentile_high])
    if not np.isfinite(low) or not np.isfinite(high) or low == high:
        low, high = np.nanmin(values), np.nanmax(values)
    return float(low), float(high)


def stats_text(values: np.ndarray) -> str:
    if values.size == 0:
        return "no valid pixels"
    unique = np.unique(values)
    parts = [
        f"min={np.nanmin(values):.3g}",
        f"max={np.nanmax(values):.3g}",
        f"mean={np.nanmean(values):.3g}",
    ]
    if unique.size <= 8:
        counts = []
        for value in unique:
            counts.append(f"{value:g}:{np.count_nonzero(values == value)}")
        parts.append("counts " + ", ".join(counts))
    return " | ".join(parts)


def band_label(
    band_index: int,
    band_names: list[str],
    descriptions: Iterable[str],
) -> str:
    descriptions = list(descriptions)
    if band_index - 1 < len(descriptions) and descriptions[band_index - 1]:
        return descriptions[band_index - 1]
    if band_index - 1 < len(band_names) and band_names[band_index - 1]:
        return band_names[band_index - 1]
    return f"Band {band_index}"


def plot_stack(
    site_name: str,
    stack_path: Path,
    output_dir: Path,
    band_names: list[str],
    max_dim: int,
    percentile_low: float,
    percentile_high: float,
    dpi: int,
) -> Path:
    if not stack_path.exists():
        raise FileNotFoundError(f"{site_name} stack not found: {stack_path}")

    with rasterio.open(stack_path) as src:
        band_count = src.count
        descriptions = src.descriptions or [""] * band_count
        cols = min(3, band_count)
        rows = int(math.ceil(band_count / cols))
        fig, axes = plt.subplots(rows, cols, figsize=(5.2 * cols, 4.8 * rows))
        axes = np.atleast_1d(axes).ravel()

        for band in range(1, band_count + 1):
            ax = axes[band - 1]
            arr = read_band_preview(src, band, max_dim)
            values = finite_values(arr)
            cmap = "gray" if is_discrete(values) else "viridis"
            vmin, vmax = display_limits(values, percentile_low, percentile_high)
            image = ax.imshow(arr, cmap=cmap, vmin=vmin, vmax=vmax)
            ax.set_title(f"Band {band}: {band_label(band, band_names, descriptions)}")
            ax.set_xlabel(stats_text(values), fontsize=8)
            ax.set_xticks([])
            ax.set_yticks([])
            fig.colorbar(image, ax=ax, fraction=0.046, pad=0.04)

        for ax in axes[band_count:]:
            ax.axis("off")

        crs_text = src.crs.to_string() if src.crs else "unknown CRS"
        fig.suptitle(
            f"{site_name} stack layers\n"
            f"{stack_path} | {src.width}x{src.height} pixels | {band_count} bands | {crs_text}",
            fontsize=12,
        )
        fig.tight_layout(rect=(0, 0, 1, 0.94))

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{clean_name(site_name).lower()}_stack_layers.png"
    fig.savefig(output_path, dpi=dpi)
    plt.close(fig)
    return output_path


def main() -> None:
    args = parse_args()
    sites = site_inputs(args)
    if not sites:
        raise SystemExit(
            "No stacks provided. Use --site Name=/path/to/stack.gri or one of "
            "--brady-stack, --desert-peak-stack, --salton-stack."
        )

    band_names = [name.strip() for name in args.band_names.split(",")]
    for site_name, stack_path in sites:
        output = plot_stack(
            site_name=site_name,
            stack_path=stack_path,
            output_dir=args.output_dir,
            band_names=band_names,
            max_dim=args.max_dim,
            percentile_low=args.percentile_low,
            percentile_high=args.percentile_high,
            dpi=args.dpi,
        )
        print(f"Wrote {site_name}: {output}")


if __name__ == "__main__":
    main()
