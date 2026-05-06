"""Insert optional one-click cells; add PIPELINE_* to config. Run: python colab/insert_oneclick_cells.py"""
import json
from pathlib import Path

p = Path(__file__).with_name("colab_1307_git_gcs.ipynb")
nb = json.loads(p.read_text(encoding="utf-8"))


def _j(c: object) -> str:
    s = c.get("source", [])  # type: ignore[union-attr]
    return s if isinstance(s, str) else "".join(s)


# Drop placeholder section 8 (markdown + code) that points at this script
for j in range(len(nb["cells"]) - 1):
    c0, c1 = nb["cells"][j], nb["cells"][j + 1]
    if c0.get("cell_type") == "markdown" and c1.get("cell_type") == "code":
        t0, t1 = _j(c0), _j(c1)
        if "## 8) One-click pipeline" in t0 and "insert_oneclick_cells.py" in t1 and "def _patch_doe_geoai" not in t1:
            del nb["cells"][j : j + 2]
            break

# 1) Config: PIPELINE_*
for c in nb["cells"]:
    if c.get("cell_type") != "code":
        continue
    t = "".join(c.get("source", []))
    if "GCS_OUTPUT_PREFIX" not in t or "DOE_DATASET_PATH" not in t:
        continue
    if "PIPELINE_RUN_BUILD" in t:
        break
    t = t.replace(
        'DOE_EXTRA_ARGS = ""\n\nGCS_OUTPUT_PREFIX',
        'DOE_EXTRA_ARGS = ""\n\n# Pipeline helpers (section 8 optional one-click flow).\n'
        "PIPELINE_RUN_BUILD = True\n"
        "PIPELINE_RUN_TRAIN = True\n"
        "PIPELINE_SYNC_AFTER_BUILD = True\n"
        "PIPELINE_SYNC_AFTER_TRAIN = True\n"
        "\n"
        "# Persistent run outputs in GCS.\n"
        "GCS_OUTPUT_PREFIX",
    )
    t = t.replace(
        "RUN_NAME_OVERRIDE = \"\"  # blank = timestamp for /content/1307_runs/...\n\n"
        "AUTO_APPEND_OUTPUT_ARGS = False",
        "RUN_NAME_OVERRIDE = \"\"  # blank = timestamp for /content/1307_runs/...\n\n"
        "# Optional: auto-append output args for scripts that support these flags.\n"
        "AUTO_APPEND_OUTPUT_ARGS = False",
    )
    c["source"] = [x + "\n" for x in t.splitlines()]
    break

PIPELINE_SRC = r'''import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

root1307 = Path(LOCAL_1307_DIR)
if not root1307.exists():
    raise FileNotFoundError(f"Missing LOCAL_1307_DIR: {root1307}")

if "LOCAL_RUN_DIR" not in globals() or "GCS_RUN_URI" not in globals():
    raise RuntimeError("Run section 6 first to initialize LOCAL_RUN_DIR and GCS_RUN_URI")

def _sync_path(local_path: Path, gcs_uri: str, label: str):
    if not local_path.exists():
        print(f"Skip sync ({label}): local path missing -> {local_path}")
        return
    run(["gsutil", "-m", "rsync", "-r", str(local_path), gcs_uri])
    print(f"Synced {label}: {local_path} -> {gcs_uri}")


def _patch_doe_geoai(path: Path):
    if not path.is_file():
        raise FileNotFoundError(f"doe_geoai.py not found: {path}")

    txt = path.read_text(encoding="utf-8", errors="ignore")
    orig = txt

    txt = re.sub(r"(?m)^\s*import\s+keras\s*$", "from tensorflow import keras", txt)
    txt = re.sub(r"(?m)^\s*from\s+keras\.callbacks\s+import\s+", "from tensorflow.keras.callbacks import ", txt)
    txt = re.sub(
        r"(?m)^\s*from\s+keras\.layers\.convolutional\s+import\s+",
        "from tensorflow.keras.layers import ",
        txt,
    )
    txt = re.sub(
        r"(?m)^\s*from\s+keras\.layers\.core\s+import\s+",
        "from tensorflow.keras.layers import ",
        txt,
    )
    txt = re.sub(r"(?m)^\s*from\s+keras\.layers\s+import\s+", "from tensorflow.keras.layers import ", txt)
    txt = re.sub(
        r"(?m)^\s*from\s+keras\.regularizers\s+import\s+",
        "from tensorflow.keras.regularizers import ",
        txt,
    )
    txt = re.sub(r"(?m)^\s*from\s+keras\.models\s+import\s+", "from tensorflow.keras.models import ", txt)
    txt = re.sub(
        r"(?m)^\s*from\s+keras\.optimizers\s+import\s+",
        "from tensorflow.keras.optimizers import ",
        txt,
    )
    txt = re.sub(r"(?m)^\s*from\s+keras\.utils\s+import\s+", "from tensorflow.keras.utils import ", txt)
    txt = re.sub(
        r"(?m)^\s*from\s+keras\s+import\s+backend\s+as\s+K\s*$",
        "from tensorflow.keras import backend as K",
        txt,
    )

    txt = re.sub(r"\bnp\.float\b", "float", txt)
    txt = re.sub(r"\bnp\.int\b", "int", txt)
    txt = re.sub(r"\bnp\.bool\b", "bool", txt)

    if "from tensorflow.keras.utils import multi_gpu_model" in txt and "def multi_gpu_model(model, gpus=None):" not in txt:
        txt = txt.replace(
            "from tensorflow.keras.utils import multi_gpu_model",
            "try:\n    from tensorflow.keras.utils import multi_gpu_model\nexcept Exception:\n    def multi_gpu_model(model, gpus=None):\n        return model",
        )

    txt = re.sub(
        r"ROC_curve_calc\(\s*testY\s*,\s*pre_y2\s*,\s*class_num\s*=\s*8\s*,",
        "ROC_curve_calc( testY, pre_y2, class_num=int(pre_y2.shape[1]),",
        txt,
    )

    if txt != orig:
        path.write_text(txt, encoding="utf-8")
        print("Patched doe_geoai.py for modern tensorflow.keras, NumPy aliases, and ROC class count")

if PIPELINE_RUN_BUILD:
    if not DOE_GRI_INPUT.strip():
        raise ValueError("PIPELINE_RUN_BUILD=True requires DOE_GRI_INPUT")

    dataset_out = Path(DOE_DATASET_OUT_DIR).resolve()
    dataset_out.parent.mkdir(parents=True, exist_ok=True)

    build_cmd = [
        sys.executable,
        str(root1307 / "create_doe_dataset.py"),
        "-i", DOE_GRI_INPUT.strip(),
        "-c", str(DOE_CHANNELS),
        "-d", str(dataset_out),
        "-s", str(DOE_SAMPLE_COUNT),
        "-k", str(DOE_KERNEL_PIXELS),
    ]
    print("$", " ".join(shlex.quote(c) for c in build_cmd))
    run(build_cmd, cwd=str(root1307))

    DOE_DATASET_PATH = str(dataset_out)
    print("PIPELINE: dataset ready ->", DOE_DATASET_PATH)

    if PIPELINE_SYNC_AFTER_BUILD and SYNC_DATASET_TO_GCS:
        out_dir = Path(DOE_DATASET_PATH).resolve()
        pfx = GCS_DATASET_PREFIX.strip().strip("/")
        if out_dir.is_dir() and pfx:
            archive = out_dir.parent / f"{out_dir.name}.tar.gz"
            if archive.exists():
                archive.unlink()
            try:
                run(["tar", "-czf", str(archive), "-C", str(out_dir.parent), out_dir.name])
                dst = f"gs://{GCS_BUCKET}/{pfx}/{archive.name}"
                run(["gsutil", "-m", "cp", str(archive), dst])
                print("PIPELINE: uploaded tile dataset archive:", dst)
                mpath = Path(LOCAL_RUN_DIR) / "run_config.json"
                if mpath.is_file():
                    meta = json.loads(mpath.read_text(encoding="utf-8"))
                    meta["dataset_archive_gcs"] = dst
                    meta["dataset_archive_local_targz"] = str(archive)
                    mpath.write_text(json.dumps(meta, indent=2), encoding="utf-8")
                try:
                    os.remove(archive)
                    print("PIPELINE: removed local", archive, "(dataset folder still on disk).")
                except OSError:
                    pass
            except subprocess.CalledProcessError:
                print("PIPELINE: dataset archive upload failed; data remains on local disk only. See error above.")
else:
    print("PIPELINE: dataset build skipped (PIPELINE_RUN_BUILD=False)")

if PIPELINE_RUN_TRAIN:
    if not DOE_DATASET_PATH.strip():
        raise ValueError("PIPELINE_RUN_TRAIN=True requires DOE_DATASET_PATH")

    doe_geoai = root1307 / "doe_geoai.py"
    _patch_doe_geoai(doe_geoai)

    labelbin = DOE_LABELBIN_PATH.strip() or str(Path(LOCAL_RUN_DIR) / "doe_labels.l")
    model = DOE_MODEL_PATH.strip() or str(Path(LOCAL_RUN_DIR) / "doe_geoai_model.h5")
    plot = DOE_PLOT_PATH.strip() or str(Path(LOCAL_RUN_DIR) / "doe_geoai_training_plot.png")
    curves = DOE_CURVES_PATH.strip() or str(Path(LOCAL_RUN_DIR) / "doe_geoai_training_curves.csv")

    train_cmd = [
        sys.executable,
        str(doe_geoai),
        "-d", DOE_DATASET_PATH.strip(),
        "-l", labelbin,
        "-m", model,
        "-p", plot,
        "-o", curves,
        "-e", str(DOE_EPOCHS),
        "-b", str(DOE_BATCH_SIZE),
        "-g", str(DOE_GPUS),
        "-k", str(DOE_KERNEL_PIXELS),
        "-c", str(DOE_CHANNELS),
    ]
    extra = DOE_EXTRA_ARGS.strip()
    if extra:
        train_cmd.extend(shlex.split(extra))

    print("$", " ".join(shlex.quote(c) for c in train_cmd))
    run(train_cmd, cwd=str(root1307))

    if PIPELINE_SYNC_AFTER_TRAIN:
        _sync_path(Path(LOCAL_RUN_DIR), GCS_RUN_URI, "run outputs")
else:
    print("PIPELINE: training skipped (PIPELINE_RUN_TRAIN=False)")
'''

md1 = {
    "cell_type": "markdown",
    "metadata": {},
    "source": [
        "## 8) One-click pipeline run (optional)\n",
        "\n",
        "Runs, in order: build `create_doe_dataset`, train with `doe_geoai` if enabled, pack the tile set as a single `.tar.gz` to GCS (same as section 7) when `PIPELINE_SYNC_AFTER_BUILD` and `SYNC_DATASET_TO_GCS`, and sync the run directory when `PIPELINE_SYNC_AFTER_TRAIN`.\n",
        "\n",
        "Run sections 2, 4, and **6** first. If your dataset is already in `DOE_DATASET_PATH`, set `PIPELINE_RUN_BUILD = False`.\n",
    ],
}
code_lines = [ln + "\n" for ln in PIPELINE_SRC.splitlines()]
cd1 = {"cell_type": "code", "metadata": {"execution_count": None, "outputs": []}, "source": code_lines}

s_dump = json.dumps(nb)
# Placeholder section 8 mentions "One-click" but is not the full pipeline — detect real cell.
if "_patch_doe_geoai" in s_dump:
    p.write_text(json.dumps(nb, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("Notebook already has full one-click code; only config was updated (if needed).", p)
else:
    idx = next(
        i
        for i, c in enumerate(nb["cells"])
        if c.get("cell_type") == "markdown" and "Sync the run folder to GCS" in "".join(c.get("source", []))
    )
    for c in nb["cells"]:
        if c.get("cell_type") == "markdown" and "Sync the run folder to GCS" in "".join(c.get("source", [])):
            c["source"] = [
                "## 9) Sync the run folder to GCS\n",
                "\n",
                "Uploads `/content/1307_runs/...` (manifest, future logs) to `GCS_RUN_URI`.\n",
                "The **tile dataset** is packed as one **`.tar.gz`** and uploaded with `gsutil cp` (fast vs thousands of `rsync`d files) when `SYNC_DATASET_TO_GCS` is True. To use it in a new session: `gsutil cp` the archive down, then `tar -xzf` into `DOE_DATASET_PATH` (or the path you pass to `doe_geoai.py`).\n",
            ]
            break
    nb["cells"] = nb["cells"][:idx] + [md1, cd1] + nb["cells"][idx:]
    p.write_text(json.dumps(nb, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("OK:", p, "one-click inserted before sync at index", idx)
