#!/usr/bin/env bash
# Qt WebAssembly build & serve helper
set -Eeuo pipefail

### ---------- configurable (can be overridden via env) ----------
: "${QT_VER:=6.9.2}"
: "${QT_ROOT:=$HOME/Qt}"
: "${QT_WASM_FLAVOR:=wasm_singlethread}"   # wasm_singlethread | wasm_multithread
: "${BUILD_DIR:=build-wasm}"
: "${BUILD_TYPE:=Release}"
: "${PORT:=8080}"
: "${SERVE_HOST:=0.0.0.0}"
: "${APP_HTML:=app_revo_wallet.html}"

# 显式标记 CI 环境的开关（除 GitHub/GitLab 等自带 CI=true 外，你也可自己设）
# export REVO_CI=1
### -------------------------------------------------------------

# 1) 选择 Host Qt 平台（自动：CI/Linux -> gcc_64，本机 macOS -> macos）
detect_qt_host_flavor() {
  if [[ -n "${QT_HOST_FLAVOR:-}" ]]; then
    echo "$QT_HOST_FLAVOR"; return
  fi
  if [[ -n "${REVO_CI:-}" || "${CI:-}" == "true" ]]; then
    echo "gcc_64"; return
  fi
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    MINGW*|MSYS*) echo "mingw_64" ;;
    *) echo "gcc_64" ;;
  esac
}
QT_HOST_FLAVOR="$(detect_qt_host_flavor)"

# 2) 组装路径
QT_HOST="$QT_ROOT/$QT_VER/$QT_HOST_FLAVOR"
QT_WASM="$QT_ROOT/$QT_VER/$QT_WASM_FLAVOR"
QTCMAKE_BIN="$QT_WASM/bin/qt-cmake"
TOOLCHAIN_FILE="$QT_WASM/lib/cmake/Qt6/qt.toolchain.cmake"

# 3) 打印环境信息（便于 debug）
echo "================= BUILD ENV ================="
echo "REVO_CI=${REVO_CI:-}"
echo "CI=${CI:-}"
echo "uname=$(uname -a || true)"
echo "QT_ROOT=$QT_ROOT"
echo "QT_VER=$QT_VER"
echo "QT_WASM_FLAVOR=$QT_WASM_FLAVOR"
echo "QT_WASM=$QT_WASM"
echo "QT_HOST_FLAVOR=$QT_HOST_FLAVOR"
echo "QT_HOST=$QT_HOST"

: "${EMSDK:=}"  # 允许无 EMSDK（Qt wasm 自带 clang）
echo "EMSDK=${EMSDK:-<unset>}"
echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_TYPE=$BUILD_TYPE"
echo "PORT=$PORT"
echo "SERVE_HOST=$SERVE_HOST"
echo "APP_HTML=$APP_HTML"
echo "------------------------------------------------"
command -v "$QTCMAKE_BIN" >/dev/null 2>&1 && "$QTCMAKE_BIN" --version || true
command -v cmake >/dev/null 2>&1 && cmake --version || true
command -v ninja >/dev/null 2>&1 && ninja --version || true
if [[ -n "$EMSDK" && -x "$EMSDK/upstream/emscripten/emcc" ]]; then
  "$EMSDK/upstream/emscripten/emcc" -v | head -n1 || true
fi
echo "================================================"
echo

if [[ ! -x "$QTCMAKE_BIN" ]]; then
  echo "[ERROR] qt-cmake 未找到：$QTCMAKE_BIN" >&2
  echo "        请确保已安装 Qt $QT_VER 的 $QT_WASM_FLAVOR 套件（路径形如：$QT_WASM）。" >&2
  echo "        可以调整 QT_ROOT/QT_VER/QT_WASM_FLAVOR 环境变量，或修正 CI 安装步骤。" >&2
  exit 2
fi
if [[ ! -d "$QT_WASM" ]]; then
  echo "[ERROR] Qt wasm 套件目录不存在：$QT_WASM" >&2
  exit 2
fi
if [[ ! -d "$QT_HOST" ]]; then
  echo "[WARN] Qt host 套件目录不存在：$QT_HOST" >&2
  echo "       仍会继续（多数情况下仅用于- DQT_HOST_PATH 指向 host Qt）。" >&2
fi

# 4) 配置与编译（只使用 qt-cmake；移除普通 cmake 兜底）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

"$QTCMAKE_BIN" -S . -B "$BUILD_DIR" \
  -DQT_HOST_PATH="$QT_HOST" \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -G Ninja

cmake --build "$BUILD_DIR" -j"$(getconf _NPROCESSORS_ONLN || echo 8)"

FULL_URL="http://${SERVE_HOST}:${PORT}/${APP_HTML}"
echo
echo "========== SERVE INFO =========="
echo "Serving directory : $BUILD_DIR"
echo "Entry HTML        : $APP_HTML"
echo "URL               : $FULL_URL"
echo "================================"
echo

# 6) 启动本地服务器（CI 不启服务）
if [[ -n "${REVO_CI:-}" || "${CI:-}" == "true" ]]; then
  ls -lh "$BUILD_DIR" | sed -n '1,50p' || true
  exit 0
else
  if [[ -n "$EMSDK" && -x "$EMSDK/upstream/emscripten/emrun" ]]; then
    "$EMSDK"/upstream/emscripten/emrun --no_browser --port "$PORT" "$BUILD_DIR"
  else
    python3 -m http.server "$PORT" -d "$BUILD_DIR"
  fi
fi
