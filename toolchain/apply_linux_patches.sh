#!/usr/bin/env bash
set -euo pipefail
# Apply patch series in patches/linux to the linux submodule

LINUX_DIR="${1:-linux}"
PATCH_DIR="${2:-patches/linux}"

if [[ ! -d "$PATCH_DIR" ]]; then
  echo "[i] No patches directory '$PATCH_DIR' found. Skipping patch apply."
  exit 0
fi

if ! git -C "$LINUX_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[!] '$LINUX_DIR' is not a git repo. Is it a submodule checkout?"
  exit 2
fi

echo "[i] Ensure submodule has enough history for 3-way apply (unshallow if needed)"
if git -C "$LINUX_DIR" rev-parse --is-shallow-repository >/dev/null 2>&1; then
  if [[ "$(git -C "$LINUX_DIR" rev-parse --is-shallow-repository)" == "true" ]]; then
    git -C "$LINUX_DIR" fetch --tags --unshallow || git -C "$LINUX_DIR" fetch --tags --depth=1000
  else
    git -C "$LINUX_DIR" fetch --tags
  fi
else
  git -C "$LINUX_DIR" fetch --tags || true
fi

echo "[i] Reset & clean linux tree before applying patches"
git -C "$LINUX_DIR" reset --hard
git -C "$LINUX_DIR" clean -xdf

shopt -s nullglob
PATCHES=("$PATCH_DIR"/*.patch)
if (( ${#PATCHES[@]} == 0 )); then
  echo "[i] No *.patch found under $PATCH_DIR. Nothing to apply."
  exit 0
fi

echo "[i] Applying patches from $PATCH_DIR ..."
git -C "$LINUX_DIR" config user.name  "ci-bot"
git -C "$LINUX_DIR" config user.email "ci-bot@localhost"

for p in "${PATCHES[@]}"; do
  patch_abs="$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
  echo "  -> $(basename "$p")"
  if ! git -C "$LINUX_DIR" am --3way --ignore-whitespace "$patch_abs"; then
    echo "[!] 3-way apply failed for $(basename "$p"), retry without 3-way..."
    git -C "$LINUX_DIR" am --abort || true
    git -C "$LINUX_DIR" am --ignore-whitespace "$patch_abs"
  fi
done

echo "[✓] Patches applied."