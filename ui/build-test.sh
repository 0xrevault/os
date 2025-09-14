#!/usr/bin/env bash
# Qt WebAssembly build & serve helper (vanilla CMake version)
set -Eeuo pipefail

### ---------- configurable (can be overridden via env) ----------
: "${QT_VER:=6.9.2}"
: "${QT_ROOT:=$HOME/Qt}"
: "${QT_WASM_FLAVOR:=wasm_singlethread}"   # wasm_singlethread | wasm_multithread
: "${BUILD_DIR:=build-test}"
: "${BUILD_TYPE:=Release}"
: "${PORT:=8080}"
: "${SERVE_HOST:=0.0.0.0}"
: "${APP_HTML:=app_revo_wallet.html}"

if [[ -n "${QT_ROOT_DIR:-}" ]]; then
  QT_ROOT="$(dirname "$(dirname "$QT_ROOT_DIR")")"
fi

# 显式标记 CI 环境（除 GitHub/GitLab 自带 CI=true 外，也可自己设 REVO_CI=1）
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

: "${EMSDK:=}"  # 允许无 EMSDK（Qt wasm 套件自带 clang/llvm）
echo "EMSDK=${EMSDK:-<unset>}"
echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_TYPE=$BUILD_TYPE"
echo "PORT=$PORT"
echo "SERVE_HOST=$SERVE_HOST"
echo "APP_HTML=$APP_HTML"
echo "------------------------------------------------"
command -v cmake >/dev/null 2>&1 && cmake --version || true
command -v ninja >/dev/null 2>&1 && ninja --version || true
if [[ -n "$EMSDK" && -x "$EMSDK/upstream/emscripten/emcc" ]]; then
  "$EMSDK/upstream/emscripten/emcc" -v | head -n1 || true
fi
echo "================================================"
echo

# 4) 基础校验（不再依赖 qt-cmake，仅要求 toolchain & 目录存在）
if [[ ! -d "$QT_WASM" ]]; then
  echo "[ERROR] Qt wasm 套件目录不存在：$QT_WASM" >&2
  exit 2
fi
if [[ ! -f "$TOOLCHAIN_FILE" ]]; then
  echo "[ERROR] 未找到 Qt wasm toolchain 文件：$TOOLCHAIN_FILE" >&2
  echo "        请确认 Qt $QT_VER 的 $QT_WASM_FLAVOR 套件已正确安装。" >&2
  exit 2
fi
if [[ ! -d "$QT_HOST" ]]; then
  echo "[WARN] Qt host 套件目录不存在：$QT_HOST" >&2
  echo "       仍会继续（-DQT_HOST_PATH 需要可用的 host Qt）。" >&2
fi

# 5) 配置与编译（使用 vanilla cmake）
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 关键点：
# - 使用 Qt 提供的 wasm toolchain（qt.toolchain.cmake）
# - 指定 host Qt 路径，供 qmlcachegen、rcc 等 host 工具使用
# - 一般无需再手动设 CMAKE_PREFIX_PATH（toolchain 已处理），但保留可覆盖能力
CMAKE_PREFIX_PATH_DEFAULT="${CMAKE_PREFIX_PATH:-}"
cmake -S . -B "$BUILD_DIR" \
  -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DQT_HOST_PATH="$QT_HOST" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  ${CMAKE_PREFIX_PATH_DEFAULT:+-DCMAKE_PREFIX_PATH="$CMAKE_PREFIX_PATH_DEFAULT"}

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