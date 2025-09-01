#!/usr/bin/env bash
set -euo pipefail
# Apply patch series in patches/linux to the linux submodule

LINUX_DIR="${1:-linux}"
PATCH_DIR="${2:-patches/linux}"

if [[ ! -d "$PATCH_DIR" ]]; then
  echo "[i] No patches directory '$PATCH_DIR' found. Skipping patch apply."
  exit 0
fi

if [[ ! -d "$LINUX_DIR/.git" ]]; then
  echo "[!] '$LINUX_DIR' is not a git repo. Is it a submodule checkout?"
  exit 2
fi

echo "[i] Reset & clean linux tree before applying patches"
git -C "$LINUX_DIR" reset --hard
git -C "$LINUX_DIR" clean -xdf

# Guard: fail early if any patch fails
shopt -s nullglob
PATCHES=("$PATCH_DIR"/*.patch)
if (( ${#PATCHES[@]} == 0 )); then
  echo "[i] No *.patch found under $PATCH_DIR. Nothing to apply."
  exit 0
fi

echo "[i] Applying patches from $PATCH_DIR ..."
for p in "${PATCHES[@]}"; do
  echo "  -> $(basename "$p")"
  git -C "$LINUX_DIR" am --3way --ignore-whitespace "$p"
done

echo "[✓] Patches applied."