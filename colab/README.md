# Cloud: GDB on GCS + Google Colab

Use this when **Windows GDAL returns Permission denied** on local `.gdb` rasters. Flow:

1. **Upload** `1303/DOE_GDB` from your PC to a **GCS bucket** (same folder layout).
2. Open **`colab_gdb_from_gcs.ipynb`** in **Google Colab**, point it at your bucket, and run cells on **Linux** (usually no Windows lock issues).

## One-time: Google Cloud

1. Create / pick a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable **Cloud Storage API**.
3. Create a bucket (region near you; uniform access is fine).
4. Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) on Windows **or** use Colab-only auth and upload via Colab’s **Drive** + manual `gsutil` from Colab.

## Upload from Windows (recommended: `gsutil`)

In **Command Prompt** or **PowerShell** (after `gcloud init`):

```bat
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

gsutil -m rsync -r "C:\Users\gmalo\GIS Final Project\1303\DOE_GDB" gs://YOUR_BUCKET/doe-gdb/
```

`-m` uses parallel workers; good for many small GDB internal files.

Optional: sync whole project folder (1304–1307) by changing the source path.

## Colab

**Recommended:** open [colab.research.google.com](https://colab.research.google.com/) and **upload** `colab_gdb_from_gcs.ipynb` (most reliable). The VS Code / Cursor Colab extension can hit websocket/widget issues — see **`colab/TROUBLESHOOTING_VSCODE_COLAB.md`**.

### Run 1307 Geothermal AI: Git for code, GCS for data (`colab_1307_from_gcs.ipynb`)

Use **`colab/colab_1307_from_gcs.ipynb`** for Colab GPU runs.

1. Open `colab/colab_1307_from_gcs.ipynb` (from this repo in Colab or upload the file).
2. In the config cell, set `GCP_PROJECT`, `GCS_BUCKET`, `GIT_REPO_URL` / `GIT_BRANCH` (fork if needed), and `GCS_EXTRA_SYNC_PREFIXES` for rasters.
3. Colab **clones or pulls** the repo into `/content/GeothermalAI` and runs scripts under **`Git_1307/`** (`doe_geoai.py`, `create_doe_dataset.py`, etc.). Training code is always taken from GitHub, not from GCS.
4. Large **data** (e.g. Brady SOM): `gsutil rsync` from your bucket into `/content/...` via `GCS_EXTRA_SYNC_PREFIXES`. **Tile archives** for training can be uploaded as a single `.tar.gz` to `GCS_DATASET_PREFIX` when `create_doe_dataset.py` finishes with `SYNC_DATASET_TO_GCS` enabled. **Run folders** under `/content/1307_runs/...` are local unless you copy them with `gsutil` or the console (see the “After §7” cell in the notebook).
5. Run cells **in order**: authenticate + Git + data sync → inspect **`Git_1307`** → install dependencies → GPU check → run folder → prep before §7 → §7 entry script → copy outputs off the VM as needed.

`requirements.txt` is taken from `Git_1307/` if present, otherwise from the **repo root** `requirements.txt`.

**Private GitHub:** use a [personal access token](https://github.com/settings/tokens) in `GIT_REPO_URL` (`https://<token>@github.com/user/repo.git`) or Colab secrets; do not commit tokens.

### Workflow: Git (code) + GCS (data)

- **Code:** `Git_1307/` in this repo, updated via `git push`; Colab re-runs section 2 to `git pull`.
- **Data & artifacts:** GCS (sync prefixes + outputs).

**Private GitHub repo:** set `GIT_REPO_URL` to `https://<TOKEN>@github.com/USER/REPO.git`, or store the token in Colab **Secrets** and build the URL in the config cell (avoid committing tokens).

1. Upload **`colab/colab_gdb_from_gcs.ipynb`** to Colab (File → Upload notebook).
2. In the config cell, set **`GCS_BUCKET`**, **`GCS_PREFIX`**, **`GCP_PROJECT`**, and (if needed) **`GIT_REPO_URL`** / **`GIT_BRANCH`**.
3. Run cells in order (micromamba first; then config → clone → GCS sync → inventory). Inventory JSON is written under `/content/`; download it or copy to Drive.

## Costs

GCS **Standard** storage is a few cents per GB-month; first-time free tier may apply. **Egress** from Colab/GCP to the internet can add cost if you download huge files repeatedly—keep working copies in the bucket and export **GeoTIFF/COG** there once you have them.
