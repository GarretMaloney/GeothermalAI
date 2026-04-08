#!/usr/bin/env python3
"""
Upload a local directory (e.g. 1303/DOE_GDB) to Google Cloud Storage.

Prefer `gsutil -m rsync -r` for huge trees; this script is for smaller uploads or CI.

Prereqs:
  pip install google-cloud-storage
  gcloud auth application-default login
  (Or set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON)

Example:
  python upload_doe_gdb_to_gcs.py --source "C:/Users/gmalo/GIS Final Project/1303/DOE_GDB" --bucket my-bucket --prefix doe-gdb/
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser(description="Upload a folder to GCS (flat blob names under prefix).")
    ap.add_argument("--source", required=True, help="Local directory to upload")
    ap.add_argument("--bucket", required=True, help="GCS bucket name (no gs://)")
    ap.add_argument(
        "--prefix",
        default="doe-gdb/",
        help="Blob prefix, use trailing slash (default doe-gdb/)",
    )
    ap.add_argument("--dry-run", action="store_true", help="List planned uploads only")
    args = ap.parse_args()

    src = Path(args.source).resolve()
    if not src.is_dir():
        print(f"Not a directory: {src}", file=sys.stderr)
        sys.exit(1)

    prefix = args.prefix.strip("/")
    if prefix:
        prefix = prefix + "/"

    try:
        from google.cloud import storage
    except ImportError:
        print("Install: pip install google-cloud-storage", file=sys.stderr)
        print("Or use: gsutil -m rsync -r SOURCE gs://BUCKET/PREFIX/", file=sys.stderr)
        sys.exit(1)

    client = storage.Client()
    bucket = client.bucket(args.bucket)
    files = [p for p in src.rglob("*") if p.is_file()]
    print(f"Uploading {len(files)} files from {src} -> gs://{args.bucket}/{prefix}", file=sys.stderr)

    for i, path in enumerate(files):
        rel = path.relative_to(src).as_posix()
        blob_name = f"{prefix}{rel}"
        if args.dry_run:
            print(blob_name)
            continue
        blob = bucket.blob(blob_name)
        blob.upload_from_filename(str(path))
        if (i + 1) % 200 == 0 or i + 1 == len(files):
            print(f"  ... {i + 1}/{len(files)}", file=sys.stderr)

    if args.dry_run:
        print(f"Dry run: {len(files)} files", file=sys.stderr)
    else:
        print("Done.", file=sys.stderr)


if __name__ == "__main__":
    main()
