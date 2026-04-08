#!/usr/bin/env python3
"""
Inspect Esri File Geodatabases (.gdb) with GDAL only (no ArcGIS/QGIS UI).

Lists vector layers (OGR) and raster datasets (GDAL OpenFileGDB). For each
raster, prints dimensions, band count, dtypes, CRS, and quick statistics so
you can check compatibility with DOE create_doe_dataset.py expectations:
  band 0 = ground-truth mask (classes 0/1), bands 1..C = model inputs.

Requires GDAL Python bindings with OpenFileGDB. Raster-in-GDB read support
needs GDAL >= 3.7 (conda-forge recommended on Windows).

Examples:
  python inspect_gdb_rasters.py --gdb "D:/GIS Final Project/1303/DOE_GDB/Bradys_Analysis.gdb"
  python inspect_gdb_rasters.py --root "D:/GIS Final Project/1303/DOE_GDB" --max-raster-read 3
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple


def _require_osgeo():
    try:
        from osgeo import gdal, ogr  # noqa: F401
    except ImportError as e:
        print(
            "Missing GDAL Python bindings.\n"
            "  conda: conda install -c conda-forge gdal\n"
            "  (pip wheels exist but are fragile on Windows; prefer conda-forge.)",
            file=sys.stderr,
        )
        raise SystemExit(1) from e
    return gdal, ogr


def _gdal_version_tuple(gdal) -> Tuple[int, ...]:
    s = gdal.VersionInfo("RELEASE_NAME")  # e.g. "3.8.4"
    parts = []
    for p in s.split("."):
        if p.isdigit():
            parts.append(int(p))
        else:
            break
    return tuple(parts)


def discover_gdbs(root: str) -> List[str]:
    out: List[str] = []
    for dirpath, dirnames, _ in os.walk(root):
        # Prune common heavy subtrees inside .gdb if any
        for d in list(dirnames):
            if d.endswith(".gdb"):
                out.append(os.path.join(dirpath, d))
    return sorted(out)


def list_vector_layers(gdal, ogr, gdb_path: str) -> List[Dict[str, Any]]:
    gdal.SetConfigOption("OGR_ORGANIZE_POLYGONS", "ONLY_CCW")
    drv = ogr.GetDriverByName("OpenFileGDB")
    if drv is None:
        return [{"error": "OpenFileGDB OGR driver not available in this GDAL build"}]
    ds = drv.Open(gdb_path, 0)
    if ds is None:
        return [{"error": f"OGR could not open: {gdb_path}"}]
    layers: List[Dict[str, Any]] = []
    for i in range(ds.GetLayerCount()):
        lyr = ds.GetLayerByIndex(i)
        name = lyr.GetName()
        geom = lyr.GetGeomType()
        # Feature count can be slow on huge layers; optional full scan elsewhere
        try:
            lyr.ResetReading()
            n = lyr.GetFeatureCount(force=0)
        except Exception:
            n = None
        layers.append(
            {
                "name": name,
                "geometry_type": ogr.GeometryTypeToName(geom) if geom else str(geom),
                "feature_count_estimate": n,
            }
        )
    ds = None
    return layers


def _collect_subdataset_names(gdal, path: str) -> List[str]:
    """Return SUBDATASET_*_NAME entries if GDAL exposes them."""
    ds = gdal.OpenEx(path, gdal.OF_READONLY)
    if ds is None:
        return []
    meta = ds.GetMetadata("SUBDATASETS") or {}
    names: List[str] = []
    i = 1
    while True:
        k = f"SUBDATASET_{i}_NAME"
        if k not in meta:
            break
        names.append(meta[k])
        i += 1
    ds = None
    return names


def _describe_raster_dataset(gdal, path_or_sub: str) -> Dict[str, Any]:
    gdal.UseExceptions()
    ds = gdal.OpenEx(
        path_or_sub,
        gdal.OF_RASTER | gdal.OF_READONLY,
        allowed_drivers=["OpenFileGDB", "GTiff", "VRT"],
    )
    if ds is None:
        return {"path": path_or_sub, "error": "gdal.OpenEx(..., RASTER) returned None"}
    out: Dict[str, Any] = {
        "path": path_or_sub,
        "size": {"x": ds.RasterXSize, "y": ds.RasterYSize},
        "band_count": ds.RasterCount,
    }
    wkt = ds.GetProjection()
    if wkt:
        out["srs_wkt_preview"] = wkt[:200] + ("..." if len(wkt) > 200 else "")
    gt = ds.GetGeoTransform()
    if gt:
        out["geotransform"] = list(gt)
    bands: List[Dict[str, Any]] = []
    for b in range(1, ds.RasterCount + 1):
        rb = ds.GetRasterBand(b)
        bands.append(
            {
                "band": b,
                "dtype": gdal.GetDataTypeName(rb.DataType),
                "nodata": rb.GetNoDataValue(),
                "description": rb.GetDescription() or "",
            }
        )
    out["bands"] = bands
    ds = None
    return out


def _band_quick_stats(
    gdal,
    path_or_sub: str,
    band: int,
    max_px: int,
) -> Optional[Dict[str, Any]]:
    """Read a small central window and return min/max/mean (no nodata handling)."""
    try:
        import numpy as np
    except ImportError:
        return {"error": "numpy not installed; skip stats"}
    ds = gdal.OpenEx(
        path_or_sub,
        gdal.OF_RASTER | gdal.OF_READONLY,
        allowed_drivers=["OpenFileGDB", "GTiff", "VRT"],
    )
    if ds is None:
        return None
    raster_count = ds.RasterCount
    if band < 1 or band > raster_count:
        ds = None
        return {"error": f"band {band} out of range 1..{raster_count}"}
    rb = ds.GetRasterBand(band)
    xsize, ysize = ds.RasterXSize, ds.RasterYSize
    w = min(max_px, xsize)
    h = min(max_px, ysize)
    xoff = max(0, (xsize - w) // 2)
    yoff = max(0, (ysize - h) // 2)
    arr = rb.ReadAsArray(xoff, yoff, w, h)
    ds = None
    if arr is None:
        return {"error": "ReadAsArray returned None"}
    flat = np.asarray(arr, dtype=np.float64).ravel()
    if flat.size == 0:
        return {"note": "empty window"}
    return {
        "window": {"xoff": xoff, "yoff": yoff, "width": w, "height": h},
        "min": float(np.nanmin(flat)),
        "max": float(np.nanmax(flat)),
        "mean": float(np.nanmean(flat)),
        "finite_fraction": float(np.mean(np.isfinite(flat))),
    }


def list_raster_candidates(gdal, gdb_path: str) -> List[str]:
    """
    Build a list of GDAL raster dataset names to try for this .gdb.
    OpenFileGDB often exposes rasters as subdatasets of the .gdb path.
    """
    candidates: List[str] = []
    subs = _collect_subdataset_names(gdal, gdb_path)
    if subs:
        candidates.extend(subs)
    # Direct open sometimes works for a single-raster gdb
    ds = gdal.OpenEx(
        gdb_path,
        gdal.OF_RASTER | gdal.OF_READONLY,
        allowed_drivers=["OpenFileGDB"],
    )
    if ds is not None:
        if gdb_path not in candidates:
            candidates.insert(0, gdb_path)
        ds = None
    return candidates


def inspect_one_gdb(
    gdal,
    ogr,
    gdb_path: str,
    max_raster_read: int,
    stats_bands: List[int],
    stats_window: int,
    json_mode: bool,
) -> Dict[str, Any]:
    result: Dict[str, Any] = {
        "gdb": os.path.abspath(gdb_path),
        "gdal_release": gdal.VersionInfo("RELEASE_NAME"),
        "vectors": list_vector_layers(gdal, ogr, gdb_path),
    }
    rasters: List[Dict[str, Any]] = []
    candidates = list_raster_candidates(gdal, gdb_path)
    result["raster_subdataset_paths_found"] = candidates

    if not candidates:
        rasters.append(
            {
                "note": "No raster subdatasets found. "
                "If vectors listed OK, try GDAL 3.7+ or confirm this GDB actually stores rasters (not only mosaic paths)."
            }
        )
    for idx, sub in enumerate(candidates[: max(0, max_raster_read)]):
        info = _describe_raster_dataset(gdal, sub)
        info["candidate_index"] = idx
        if "error" not in info and stats_bands:
            info["sample_stats"] = {}
            for b in stats_bands:
                st = _band_quick_stats(gdal, sub, b, stats_window)
                if st is not None:
                    info["sample_stats"][f"band_{b}"] = st
        rasters.append(info)

    result["rasters"] = rasters
    result["doe_pipeline_hint"] = (
        "create_doe_dataset.py (via gdal_array.LoadFile + transpose) maps GDAL band 1 to "
        "numpy channel 0: channel 0 = ground-truth mask, channels 1..C = features. "
        "So GDAL band 1 must be the 0/1 (or class) mask; GDAL bands 2..(C+1) are predictors. "
        "Align band order with Moraga et al. / your GDB export."
    )
    if json_mode:
        return result

    print("=" * 72)
    print("GDB:", result["gdal_release"], "|", result["gdb"])
    print("-" * 72)
    print("Vector layers (OGR):")
    for row in result["vectors"]:
        if "error" in row:
            print("  ERROR:", row["error"])
        else:
            print(
                f"  - {row['name']}: {row['geometry_type']} "
                f"(features~{row['feature_count_estimate']})"
            )
    print("-" * 72)
    print("Raster candidates (GDAL):", len(candidates))
    for line in result["rasters"]:
        if "note" in line:
            print(" ", line["note"])
            continue
        if "error" in line:
            print("  ERROR:", line["path"], line["error"])
            continue
        print(f"  [{line.get('candidate_index')}] {line['path']}")
        print(
            f"      size {line['size']['x']} x {line['size']['y']}, "
            f"bands={line['band_count']}"
        )
        for b in line.get("bands", []):
            print(
                f"      band {b['band']}: {b['dtype']} nodata={b['nodata']} "
                f"desc={b['description']!r}"
            )
        ss = line.get("sample_stats") or {}
        for bk, sv in ss.items():
            print(f"      stats {bk}: {sv}")
    print()
    return result


def main() -> None:
    gdal, ogr = _require_osgeo()
    gdal.UseExceptions()
    ogr.UseExceptions()

    ap = argparse.ArgumentParser(description="Inspect File GDB vectors and rasters via GDAL.")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--gdb", help="Path to one .gdb folder")
    g.add_argument("--root", help="Walk this directory tree and inspect every .gdb found")
    ap.add_argument(
        "--max-raster-read",
        type=int,
        default=5,
        help="Max raster dataset candidates to open in detail per gdb (default 5)",
    )
    ap.add_argument(
        "--stats-bands",
        default="1,2,3",
        help="Comma-separated 1-based band indices for quick central-window stats (default 1,2,3)",
    )
    ap.add_argument(
        "--stats-window",
        type=int,
        default=256,
        help="Max width/height of central window for stats (default 256)",
    )
    ap.add_argument("--json", action="store_true", help="Print one JSON object per gdb to stdout")
    args = ap.parse_args()

    v = _gdal_version_tuple(gdal)
    if v and v < (3, 7):
        print(
            f"Warning: GDAL {gdal.VersionInfo('RELEASE_NAME')} may not read rasters from "
            "FileGDB; 3.7+ recommended. Vectors may still work.\n",
            file=sys.stderr,
        )

    try:
        bands = [int(x.strip()) for x in args.stats_bands.split(",") if x.strip()]
    except ValueError:
        raise SystemExit("Invalid --stats-bands; use e.g. 1,2,3")

    gdbs: List[str] = []
    if args.gdb:
        p = os.path.expanduser(args.gdb)
        if not p.lower().endswith(".gdb") or not os.path.isdir(p):
            raise SystemExit(f"Not a directory ending in .gdb: {p}")
        gdbs = [p]
    else:
        root = os.path.expanduser(args.root)
        if not os.path.isdir(root):
            raise SystemExit(f"Not a directory: {root}")
        gdbs = discover_gdbs(root)
        if not gdbs:
            raise SystemExit(f"No .gdb folders found under {root}")

    all_results: List[Dict[str, Any]] = []
    for gdb in gdbs:
        r = inspect_one_gdb(
            gdal,
            ogr,
            gdb,
            max_raster_read=args.max_raster_read,
            stats_bands=bands,
            stats_window=args.stats_window,
            json_mode=args.json,
        )
        all_results.append(r)

    if args.json:
        print(json.dumps(all_results if len(all_results) > 1 else all_results[0], indent=2))


if __name__ == "__main__":
    main()
