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

### Workflow: Git + GCS (default in the notebook)

- **Code (`scripts/`):** Colab **clones or pulls** your GitHub repo (default `https://github.com/GarretMaloney/GeothermalAI.git`, branch `main`). Push from any computer; re-run the clone cell in Colab to pick up changes.
- **Data:** **`gsutil rsync`** from your bucket into `/content/...` (prefixes with spaces are handled via `subprocess`, not shell `!` magic).
- **Drive mount** in the notebook is **optional** — only if you keep scripts on Drive instead of Git.

**Private GitHub repo:** set `GIT_REPO_URL` to `https://<TOKEN>@github.com/USER/REPO.git`, or store the token in Colab **Secrets** and build the URL in the config cell (avoid committing tokens).

1. Upload **`colab/colab_gdb_from_gcs.ipynb`** to Colab (File → Upload notebook).
2. In the config cell, set **`GCS_BUCKET`**, **`GCS_PREFIX`**, **`GCP_PROJECT`**, and (if needed) **`GIT_REPO_URL`** / **`GIT_BRANCH`**.
3. Run cells in order (micromamba first; then config → clone → GCS sync → inventory). Inventory JSON is written under `/content/`; download it or copy to Drive.

## Costs

GCS **Standard** storage is a few cents per GB-month; first-time free tier may apply. **Egress** from Colab/GCP to the internet can add cost if you download huge files repeatedly—keep working copies in the bucket and export **GeoTIFF/COG** there once you have them.
