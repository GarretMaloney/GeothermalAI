"""
Shared helpers for File Geodatabase (.gdb) inventory and raster export (no ArcGIS).

GDR context: submission 1303 bundles geodatabases for all three sites; 1304/1305/1306 are
per-site repository labels on disk — point --root at whichever folder trees you need.

Vectors: fiona. Rasters: GDAL OpenFileGDB (subdatasets) + rasterio for metadata/copy.

Install (Windows): conda-forge for ABI-aligned binaries
  conda install -c conda-forge geopandas fiona rasterio gdal numpy
"""

from __future__ import annotations

import json
import os
import re
from typing import Any, Dict, List, Optional, Tuple

__all__ = [
    "discover_gdbs",
    "inventory_vector_layers",
    "list_raster_subdatasets",
    "describe_raster",
    "export_subdataset_to_geotiff",
    "inventory_one_gdb",
    "inventory_tree",
]


def discover_gdbs(root: str) -> List[str]:
    """Find every folder named *.gdb under root; do not descend into .gdb internals."""
    root = os.path.abspath(os.path.expanduser(root))
    out: List[str] = []
    for dirpath, dirnames, _filenames in os.walk(root):
        if dirpath.lower().endswith(".gdb"):
            dirnames.clear()
            continue
        for d in dirnames:
            if d.endswith(".gdb"):
                out.append(os.path.join(dirpath, d))
    return sorted(set(out))


def _require_fiona():
    import fiona

    return fiona


def _require_gdal():
    try:
        import bootstrap_gdal_env

        bootstrap_gdal_env.ensure_gdal_env()
    except ImportError:
        pass
    try:
        from osgeo import gdal
    except ImportError as e:
        raise ImportError(
            "GDAL Python bindings (osgeo.gdal) are required to list/export rasters inside "
            ".gdb. Fiona alone can list layer names but cannot read Esri internal raster blocks. "
            "Install: conda install -c conda-forge gdal  (Windows: avoid pip gdal without MSVC)."
        ) from e

    gdal.UseExceptions()
    return gdal


def _require_rasterio():
    import rasterio

    return rasterio


def inventory_vector_layers(
    gdb_path: str,
    *,
    include_feature_count: bool = False,
    max_count_scan: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    List vector layers using fiona (OpenFileGDB via GDAL).
    feature_count is optional; can be slow on large layers.
    """
    fiona = _require_fiona()
    gdb_path = os.path.abspath(os.path.expanduser(gdb_path))
    try:
        names = fiona.listlayers(gdb_path)
    except Exception as e:
        return [{"error": str(e), "gdb": gdb_path}]

    rows: List[Dict[str, Any]] = []
    for name in names:
        row: Dict[str, Any] = {"layer": name}
        try:
            with fiona.open(gdb_path, layer=name) as col:
                row["geometry_type"] = col.schema.get("geometry")
                row["driver"] = col.driver
                row["schema_properties"] = list((col.schema.get("properties") or {}).keys())
                crs = col.crs
                if crs is None:
                    row["crs"] = None
                elif hasattr(crs, "to_string"):
                    row["crs"] = crs.to_string()
                else:
                    row["crs"] = str(crs)
                if include_feature_count:
                    if max_count_scan is None:
                        row["feature_count"] = sum(1 for _ in col)
                    else:
                        n = 0
                        for _ in col:
                            n += 1
                            if n >= max_count_scan:
                                row["feature_count_at_least"] = max_count_scan
                                break
                        else:
                            row["feature_count"] = n
        except Exception as e:
            row["error"] = str(e)
        rows.append(row)
    return rows


def list_raster_subdatasets(gdb_path: str) -> Tuple[List[str], Optional[str]]:
    """
    Return GDAL raster dataset identifiers for rasters inside a .gdb.
    Usually SUBDATASET_*_NAME strings (GDAL 3.7+ OpenFileGDB raster support).
    """
    gdal = _require_gdal()
    try:
        from osgeo import gdalconst

        of_shared = gdalconst.OF_SHARED
    except Exception:
        of_shared = 0

    gdb_path = os.path.abspath(os.path.expanduser(gdb_path))
    open_flags = (
        gdal.OF_READONLY | gdal.OF_VECTOR | gdal.OF_RASTER | of_shared
    )
    try:
        ds = gdal.OpenEx(
            gdb_path,
            open_flags,
            allowed_drivers=["OpenFileGDB"],
        )
    except Exception as e:
        return [], f"gdal.OpenEx failed: {e}"
    if ds is None:
        return [], "gdal.OpenEx(gdb) returned None (check GDAL/OpenFileGDB and GDAL >= 3.7 for rasters)"
    meta = ds.GetMetadata("SUBDATASETS") or {}
    names: List[str] = []
    i = 1
    while True:
        k = f"SUBDATASET_{i}_NAME"
        if k not in meta:
            break
        names.append(meta[k])
        i += 1

    # If no SUBDATASET metadata, the first open may already expose raster bands (do this
    # BEFORE closing ds). A second raster-only OpenEx fails with Permission denied on some
    # Windows setups even when the combined open succeeded.
    if not names:
        try:
            if ds.RasterCount and ds.RasterCount > 0:
                names.append(gdb_path)
        except Exception:
            pass

    ds = None

    # Last resort: raster-only open (often redundant; can error on Windows)
    if not names:
        try:
            rds = gdal.OpenEx(
                gdb_path,
                gdal.OF_RASTER | gdal.OF_READONLY | of_shared,
                allowed_drivers=["OpenFileGDB"],
            )
            if rds is not None:
                names.append(gdb_path)
                rds = None
        except Exception as e:
            return [], f"Raster open skipped: {e}"

    return names, None


def _friendly_raster_name(subdataset_uri: str, gdb_path: str) -> str:
    """Derive a filesystem-safe stem for output filenames."""
    g = os.path.abspath(gdb_path)
    s = subdataset_uri
    if s.startswith(g):
        tail = s[len(g) :].lstrip("\\/")
        tail = re.sub(r"[^\w\-.]+", "_", tail)
        return tail or "raster"
    s = re.sub(r"[^\w\-.]+", "_", s)
    return s[-120:] if len(s) > 120 else s


def describe_raster(subdataset_uri: str) -> Dict[str, Any]:
    """Band count, shape, dtypes, CRS using rasterio (GDAL underneath)."""
    rasterio = _require_rasterio()
    out: Dict[str, Any] = {"source": subdataset_uri}
    try:
        with rasterio.open(subdataset_uri) as src:
            out["width"] = src.width
            out["height"] = src.height
            out["count"] = src.count
            out["dtypes"] = [src.dtypes[i] for i in range(src.count)]
            out["crs"] = src.crs.to_string() if src.crs else None
            out["transform"] = list(src.transform)[:6]
            out["nodata"] = [src.nodatavals[i] for i in range(src.count)]
    except Exception as e:
        out["error"] = str(e)
    return out


def export_subdataset_to_geotiff(
    subdataset_uri: str,
    dest_path: str,
    *,
    compress: str = "deflate",
    tiled: bool = True,
    bigtiff: str = "IF_SAFER",
    predictor: int = 2,
) -> Dict[str, Any]:
    """
    Write a GeoTIFF. Tries rasterio.shutil.copy first; falls back to gdal.Translate.
    """
    os.makedirs(os.path.dirname(os.path.abspath(dest_path)) or ".", exist_ok=True)
    dest_path = os.path.abspath(dest_path)
    result: Dict[str, Any] = {"source": subdataset_uri, "dest": dest_path}

    rasterio = _require_rasterio()
    try:
        from rasterio.shutil import copy as rio_copy

        with rasterio.Env():
            rio_copy(
                subdataset_uri,
                dest_path,
                driver="GTiff",
                compress=compress,
                tiled=tiled,
                BIGTIFF=bigtiff,
                PREDICTOR=predictor,
            )
        result["method"] = "rasterio.shutil.copy"
        return result
    except Exception as e:
        result["rasterio_error"] = str(e)

    gdal = _require_gdal()
    opts = [
        f"COMPRESS={compress.upper()}",
        f"TILED={'YES' if tiled else 'NO'}",
        f"BIGTIFF={bigtiff}",
        f"PREDICTOR={predictor}",
    ]
    gdal.Translate(dest_path, subdataset_uri, format="GTiff", creationOptions=opts)
    result["method"] = "gdal.Translate"
    return result


def inventory_one_gdb(
    gdb_path: str,
    *,
    include_vector_feature_count: bool = False,
    vector_count_max_scan: Optional[int] = None,
) -> Dict[str, Any]:
    gdb_path = os.path.abspath(os.path.expanduser(gdb_path))
    rec: Dict[str, Any] = {
        "gdb": gdb_path,
        "gdb_basename": os.path.basename(gdb_path),
        "vectors": inventory_vector_layers(
            gdb_path,
            include_feature_count=include_vector_feature_count,
            max_count_scan=vector_count_max_scan,
        ),
    }
    try:
        gdal = _require_gdal()
    except ImportError as e:
        rec["gdal_release"] = None
        rec["raster_subdatasets"] = []
        rec["rasters"] = []
        rec["raster_note"] = str(e)
        return rec

    rec["gdal_release"] = gdal.VersionInfo("RELEASE_NAME")
    subs, err = list_raster_subdatasets(gdb_path)
    rec["raster_subdatasets"] = subs
    if err:
        rec["raster_note"] = err
    rasters: List[Dict[str, Any]] = []
    for sub in subs:
        d = describe_raster(sub)
        d["suggested_filename_stem"] = _friendly_raster_name(sub, gdb_path)
        rasters.append(d)
    rec["rasters"] = rasters
    return rec


def inventory_tree(
    root: str,
    *,
    include_vector_feature_count: bool = False,
    vector_count_max_scan: Optional[int] = None,
) -> Dict[str, Any]:
    root = os.path.abspath(os.path.expanduser(root))
    gdbs = discover_gdbs(root)
    return {
        "root": root,
        "gdb_count": len(gdbs),
        "gdbs": [
            inventory_one_gdb(
                g,
                include_vector_feature_count=include_vector_feature_count,
                vector_count_max_scan=vector_count_max_scan,
            )
            for g in gdbs
        ],
    }


def write_json(path: str, data: Any) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(path)) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
