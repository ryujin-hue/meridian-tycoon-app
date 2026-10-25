#!/usr/bin/env bash
# sync_data.sh — Salin snapshot data terkini daripada repo data ke assets/data/
# Guna: [DATA_REF=main] bash tool/sync_data.sh
# CI TIDAK menjalankan skrip ini — snapshot yang dikomit digunakan semasa binaan.
set -euo pipefail

DATA_REF="${DATA_REF:-main}"
SRC="${1:-/tmp/meridian-tycoon-data}"
REPO_URL="https://github.com/ryujin-hue/meridian-tycoon-data.git"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/assets/data"

if [ ! -d "$SRC/.git" ]; then
  echo "Klon repo data ($DATA_REF) ke $SRC ..."
  rm -rf "$SRC"
  git clone --depth 1 --branch "$DATA_REF" "$REPO_URL" "$SRC"
fi

REQUIRED=(balance tiers sectors operations companies ai_ceos staff_roles staff_pool research events seasons cosmetics milestones tutorial leaderboard_bots)
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"
for f in "${REQUIRED[@]}"; do
  cp "$SRC/game-data/$f.json" "$TMP/"
done
mkdir -p "$TMP/i18n"
for l in en ms id; do
  cp "$SRC/game-data/i18n/$l.json" "$TMP/i18n/"
done

# Sahkan JSON sah sebelum menukar (atomic swap)
SNAPSHOT_DIR="$TMP" python3 - <<'PY'
import json, sys, pathlib, os
tmp = pathlib.Path(os.environ["SNAPSHOT_DIR"])
required = ["balance","tiers","sectors","operations","companies","ai_ceos","staff_roles",
            "staff_pool","research","events","seasons","cosmetics","milestones","tutorial",
            "leaderboard_bots"]
files = {f"{r}.json": json.loads((tmp/f"{r}.json").read_text()) for r in required}
for l in ("en","ms","id"):
    files[f"i18n/{l}.json"] = json.loads((tmp/"i18n"/f"{l}.json").read_text())
versions = {v["dataVersion"] for v in files.values()}
assert len(versions) == 1, f"dataVersion tidak seragam: {versions}"
en = set(files["i18n/en.json"]["strings"])
for l in ("ms","id"):
    s = set(files["i18n/{l}.json".format(l=l)]["strings"])
    assert en == s, f"Pariti kunci i18n gagal: {l}"
bal = files["balance.json"]
assert 1.0 <= bal["upgradeCostGrowth"] <= 2.0
print("Validasi snapshot OK:", versions.pop())
PY

# Tukar atomik
rm -rf "$DEST.new"
mv "$DEST" "$DEST.old" 2>/dev/null || true
cp -r "$TMP" "$DEST.new"
rm -rf "$DEST.old"
rm -rf "$DEST"
mv "$DEST.new" "$DEST"

echo "Snapshot data disalin ke assets/data/ (dikomit untuk CI & offline)."
echo "JANGAN edit fail di assets/data/ — sumber kebenaran ialah repo data."
