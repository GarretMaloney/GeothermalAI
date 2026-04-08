#!/usr/bin/env python3
"""
Inventory all vector and raster layers in Esri File Geodatabases under a root path.

Outputs JSON suitable for export_gdb_rasters_to_geotiff.py and for your report.

Example:
  python inventory_gdbs.py --root "D:/GIS Final Project/1303/DOE_GDB" -o "D:/GIS Final Project/exports/inventory_1303.json"
"""

from __future__ import annotations

import argparse
import json
import sys

# Allow `python scripts/inventory_gdbs.py` from repo root
if __package__ is None and __name__ == "__main__":
    _scripts = __import__("pathlib").Path(__file__).resolve().parent
    if str(_scripts) not in sys.path:
        sys.path.insert(0, str(_scripts))

try:
    import bootstrap_gdal_env  # noqa: E402

    bootstrap_gdal_env.ensure_gdal_env()
except ImportError:
    pass

from gdb_tools import inventory_tree, write_json  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser(description="Inventory .gdb vectors (fiona) and rasters (GDAL/rasterio).")
    ap.add_argument("--root", required=True, help="Directory tree to search for *.gdb folders")
    ap.add_argument(
        "-o",
        "--output",
        help="Write JSON to this path (default: print to stdout)",
    )
    ap.add_argument(
        "--count-features",
        action="store_true",
        help="Count vector features per layer (can be slow)",
    )
    ap.add_argument(
        "--count-max-scan",
        type=int,
        default=None,
        help="If set with --count-features, stop after this many features per layer (reports at_least)",
    )
    args = ap.parse_args()

    data = inventory_tree(
        args.root,
        include_vector_feature_count=args.count_features,
        vector_count_max_scan=args.count_max_scan,
    )

    if args.output:
        write_json(args.output, data)
        print(f"Wrote {args.output} ({data['gdb_count']} geodatabases)", file=sys.stderr)
    else:
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
