#!/usr/bin/env python3
"""
Export raster datasets from File Geodatabases to GeoTIFF on disk (then you can gsutil/rsync to GCS).

Uses rasterio.shutil.copy when possible; falls back to gdal.Translate for stubborn OpenFileGDB paths.

Example:
  python export_gdb_rasters_to_geotiff.py --inventory "D:/exports/inventory_1303.json" --out-dir "D:/exports/geotiff_1303"
  python export_gdb_rasters_to_geotiff.py --root "D:/GIS Final Project/1303/DOE_GDB" --out-dir "D:/exports/geotiff_1303"
"""

from __future__ import annotations

import argparse
import json
import os
import sys

if __package__ is None and __name__ == "__main__":
    _scripts = __import__("pathlib").Path(__file__).resolve().parent
    if str(_scripts) not in sys.path:
        sys.path.insert(0, str(_scripts))

try:
    import bootstrap_gdal_env  # noqa: E402

    bootstrap_gdal_env.ensure_gdal_env()
except ImportError:
    pass

from gdb_tools import (  # noqa: E402
    discover_gdbs,
    export_subdataset_to_geotiff,
    list_raster_subdatasets,
    _friendly_raster_name,
)


def main() -> None:
    ap = argparse.ArgumentParser(description="Export GDB rasters to GeoTIFF.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--inventory", help="JSON from inventory_gdbs.py")
    src.add_argument("--root", help="Scan this tree for .gdb and export all rasters found")
    ap.add_argument("--out-dir", required=True, help="Output directory for .tif files")
    ap.add_argument(
        "--compress",
        default="deflate",
        help="GTiff compression (default deflate); use ZSTD on GDAL if available",
    )
    ap.add_argument("--no-tiled", action="store_true", help="Write stripped TIFF instead of tiled")
    ap.add_argument("--dry-run", action="store_true", help="Print planned outputs only")
    args = ap.parse_args()

    out_dir = os.path.abspath(os.path.expanduser(args.out_dir))
    os.makedirs(out_dir, exist_ok=True)

    jobs: list[tuple[str, str, str]] = []  # gdb_path, sub_uri, dest_path

    if args.inventory:
        with open(args.inventory, encoding="utf-8") as f:
            inv = json.load(f)
        blocks = inv.get("gdbs") or [inv]
        for block in blocks:
            gdb = block.get("gdb")
            if not gdb:
                continue
            subs = block.get("raster_subdatasets") or []
            if not subs:
                subs, _ = list_raster_subdatasets(gdb)
            for sub in subs:
                stem = _friendly_raster_name(sub, gdb)
                base = f"{os.path.basename(gdb)}__{stem}.tif"
                base = "".join(c if c not in '<>:"/\\|?*' else "_" for c in base)
                dest = os.path.join(out_dir, base)
                jobs.append((gdb, sub, dest))
    else:
        for gdb in discover_gdbs(args.root):
            subs, _ = list_raster_subdatasets(gdb)
            for sub in subs:
                stem = _friendly_raster_name(sub, gdb)
                base = f"{os.path.basename(gdb)}__{stem}.tif"
                base = "".join(c if c not in '<>:"/\\|?*' else "_" for c in base)
                dest = os.path.join(out_dir, base)
                jobs.append((gdb, sub, dest))

    manifest: list[dict] = []
    for gdb, sub, dest in jobs:
        rec = {"gdb": gdb, "source": sub, "dest": dest}
        if args.dry_run:
            print(f"[dry-run] {sub} -> {dest}")
        else:
            try:
                exp = export_subdataset_to_geotiff(
                    sub,
                    dest,
                    compress=args.compress,
                    tiled=not args.no_tiled,
                )
                rec.update(exp)
                print(exp.get("method"), dest, file=sys.stderr)
            except Exception as e:
                rec["error"] = str(e)
                print(f"FAIL {sub}: {e}", file=sys.stderr)
        manifest.append(rec)

    manifest_path = os.path.join(out_dir, "export_manifest.json")
    if not args.dry_run:
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        print(f"Wrote manifest {manifest_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
