#!/usr/bin/env python3
"""
Download an archive from a public HTTPS URL, extract it locally, and upload the
extracted tree to Google Cloud Storage with ``gsutil -m rsync -r``.

GCS does not unzip objects in place; extraction always happens on the machine
running this script (e.g. Colab VM or your PC with gcloud installed).

**Colab** (authenticate first, e.g. ``auth.authenticate_user()`` and
``gcloud config set project YOUR_PROJECT``; ``gsutil`` must be on ``PATH``)::

    !python /content/GeothermalAI/scripts/download_url_extract_upload_gcs.py \\
        --url \"https://example.org/geothermal_dataset.zip\" \\
        --bucket gis-final-project \\
        --gcs-prefix \"GIS Final Project/ingest/geothermal-data-repository\" \\
        --work-dir /content/_geothermal_ingest

**Local** (Google Cloud SDK installed)::

    python scripts/download_url_extract_upload_gcs.py ^
        --url https://... ^
        --bucket my-bucket ^
        --gcs-prefix path/under/bucket
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading:\n  {url}\n  -> {dest}")
    with urllib.request.urlopen(url) as resp, open(dest, "wb") as out:
        shutil.copyfileobj(resp, out, length=1024 * 1024)
    print(f"Saved {dest.stat().st_size} bytes")


def _tar_extractall(t: tarfile.TarFile, out_dir: Path) -> None:
    if sys.version_info >= (3, 12):
        t.extractall(out_dir, filter="data")
    else:
        t.extractall(out_dir)


def extract(archive: Path, out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    lower = archive.name.lower()

    if lower.endswith(".zip") or zipfile.is_zipfile(archive):
        print(f"Extracting zip -> {out_dir}")
        with zipfile.ZipFile(archive, "r") as z:
            z.extractall(out_dir)
        return

    if lower.endswith((".tar.gz", ".tgz")):
        print(f"Extracting tar.gz -> {out_dir}")
        with tarfile.open(archive, "r:gz") as t:
            _tar_extractall(t, out_dir)
        return

    if lower.endswith(".tar") and tarfile.is_tarfile(archive):
        print(f"Extracting tar -> {out_dir}")
        with tarfile.open(archive, "r") as t:
            _tar_extractall(t, out_dir)
        return

    if tarfile.is_tarfile(archive):
        print(f"Extracting tar (auto) -> {out_dir}")
        with tarfile.open(archive) as t:
            _tar_extractall(t, out_dir)
        return

    raise SystemExit(
        f"Unsupported archive type: {archive.name}\n"
        "Supported: .zip, .tar.gz, .tgz, .tar"
    )


def run_gsutil(argv: list[str]) -> None:
    print("$", " ".join(argv))
    subprocess.run(argv, check=True)


def _bucket_only(raw: str) -> str:
    s = raw.strip()
    if s.startswith("gs://"):
        s = s[5:]
    return s.split("/")[0]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Download URL -> extract locally -> gsutil rsync extracted tree to GCS."
    )
    parser.add_argument(
        "--url",
        required=True,
        help="URL to a .zip or .tar/.tar.gz archive (must be directly downloadable)",
    )
    parser.add_argument("--bucket", required=True, help="Bucket name (e.g. gis-final-project)")
    parser.add_argument(
        "--gcs-prefix",
        required=True,
        help="Destination prefix inside the bucket (no leading slash), e.g. GIS Final Project/ingest/foo",
    )
    parser.add_argument(
        "--work-dir",
        default="",
        help="Local folder for download + extract (default: ./.ingest_<file_stem>)",
    )
    parser.add_argument(
        "--also-upload-archive",
        action="store_true",
        help="Also gsutil cp the raw downloaded file under .../archives/ next to the parent of --gcs-prefix",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Download and extract only; print gsutil commands, do not upload",
    )
    args = parser.parse_args()

    bucket = _bucket_only(args.bucket)
    prefix = args.gcs_prefix.strip().strip("/")

    name = args.url.rstrip("/").split("/")[-1] or "download.bin"
    if "?" in name:
        name = name.split("?")[0]

    if args.work_dir:
        work_root = Path(args.work_dir).resolve()
    else:
        work_root = (Path(".") / f".ingest_{Path(name).stem}").resolve()

    archive_path = work_root / name
    extract_dir = work_root / "extracted"

    work_root.mkdir(parents=True, exist_ok=True)
    if extract_dir.exists():
        shutil.rmtree(extract_dir)

    try:
        download(args.url, archive_path)
    except urllib.error.URLError as e:
        raise SystemExit(f"Download failed: {e}") from e

    extract(archive_path, extract_dir)

    dest_uri = f"gs://{bucket}/{prefix}"
    rsync_cmd = ["gsutil", "-m", "rsync", "-r", str(extract_dir), dest_uri]
    if args.dry_run:
        print("Dry run — would run:\n ", " ".join(rsync_cmd))
    else:
        run_gsutil(rsync_cmd)
        print(f"Synced extracted tree to {dest_uri}/")

    if args.also_upload_archive:
        parent_prefix = prefix.rsplit("/", 1)[0] if "/" in prefix else prefix
        arch_uri = f"gs://{bucket}/{parent_prefix}/archives/{archive_path.name}"
        cp_cmd = ["gsutil", "-m", "cp", str(archive_path), arch_uri]
        if args.dry_run:
            print("Dry run — would run:\n ", " ".join(cp_cmd))
        else:
            run_gsutil(cp_cmd)
            print(f"Uploaded archive to {arch_uri}")


if __name__ == "__main__":
    main()
