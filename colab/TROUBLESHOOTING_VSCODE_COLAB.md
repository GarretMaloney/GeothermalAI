# Colab in Cursor / VS Code — common issues

## Kernel picker / websocket / “Server sent no subprotocol”

The **Google Colab** extension talks to a remote runtime over WebSocket. Cursor/VS Code builds sometimes break that handshake.

**Fix (most reliable):** run the notebook in the **browser**: [colab.research.google.com](https://colab.research.google.com/) → **File → Upload notebook** → choose `colab_gdb_from_gcs.ipynb`.

**In the extension:** try **Colab CPU → New Colab Server**, wait until it shows connected, then run cells. Update the **Colab** and **Jupyter** extensions to the latest versions.

## `Failed to fetch` / `unpkg.com` (widgets)

Some UI pieces try to load from CDN. If your network blocks them:

- Try another network or disable strict VPN/ad-block for Cursor.
- In this repo, **`.vscode/settings.json`** points widget scripts at **jsdelivr** as a fallback (open the folder in VS Code/Cursor so settings apply).

## Kernel crash after `condacolab`

**condacolab** forces a **kernel restart**. The Colab-in-editor bridge often **does not survive** that cleanly.

**Fix:** this project’s notebook now uses **micromamba** into `/content/geo-env` with **no restart** — use the current `colab_gdb_from_gcs.ipynb`.

## Wrong Google Cloud project

Use the **Project ID** from the console (e.g. `maloney-geog-473`), not the display name (`Maloney-Geog`).
