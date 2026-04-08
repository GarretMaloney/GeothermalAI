"""Set GDAL_DATA / PROJ_LIB for conda-forge Windows layouts before importing osgeo."""
from __future__ import annotations

import os
import sys


def ensure_gdal_env() -> None:
    if os.environ.get("GDAL_DATA") and os.environ.get("PROJ_LIB"):
        return
    # conda-forge: <prefix>/Library/share/gdal and proj
    candidates = [
        os.path.join(sys.prefix, "Library", "share"),
        os.path.join(sys.prefix, "share"),
    ]
    for root in candidates:
        gd = os.path.join(root, "gdal")
        pj = os.path.join(root, "proj")
        if os.path.isdir(gd):
            os.environ.setdefault("GDAL_DATA", gd)
        if os.path.isdir(pj):
            os.environ.setdefault("PROJ_LIB", pj)
        if os.environ.get("GDAL_DATA") and os.environ.get("PROJ_LIB"):
            return
