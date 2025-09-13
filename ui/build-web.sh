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
# 如果你的 HTML 产物名不同，可通过 APP_HTML 覆盖；否则脚本会自动猜。
: "${APP_HTML:=}"

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
QTCMAKE_BIN="$QT_WASM/bin/qt-cmake"   # 优先用目标套件内的 qt-cmake
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

# Allow running without an external emsdk (Qt wasm ships its own clang); avoid
# unbound variable errors when EMSDK is undefined in CI.
: "${EMSDK:=}"

echo "EMSDK=${EMSDK:-<unset>}"
echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_TYPE=$BUILD_TYPE"
echo "PORT=$PORT"
echo "SERVE_HOST=$SERVE_HOST"
echo "APP_HTML(env)=${APP_HTML:-<auto>}"
echo "------------------------------------------------"
command -v "$QTCMAKE_BIN" >/dev/null 2>&1 && "$QTCMAKE_BIN" --version || true
command -v cmake >/dev/null 2>&1 && cmake --version || true
command -v ninja >/dev/null 2>&1 && ninja --version || true
# Show emcc version only if emsdk path available
if [[ -n "$EMSDK" && -x "$EMSDK/upstream/emscripten/emcc" ]]; then
  "$EMSDK/upstream/emscripten/emcc" -v | head -n1 || true
fi
echo "================================================"
echo

# 4) 配置与编译
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

if [[ -x "$QTCMAKE_BIN" ]]; then
  # qt-cmake 会自动带上 toolchain；仍显式传 QT_HOST_PATH
  "$QTCMAKE_BIN" -S . -B "$BUILD_DIR" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -G Ninja
else
  # 兜底：用标准 cmake + toolchain
  cmake -S . -B "$BUILD_DIR" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DQT_HOST_PATH="$QT_HOST" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -G Ninja
fi

cmake --build "$BUILD_DIR" -j"$(getconf _NPROCESSORS_ONLN || echo 8)"

# 5) 解析 HTML 文件名（优先使用 env 覆盖；否则自动猜测）
if [[ -z "${APP_HTML:-}" ]]; then
  for cand in app_revo_wallet.html index.html; do
    if [[ -f "$BUILD_DIR/$cand" ]]; then APP_HTML="$cand"; break; fi
  done
  if [[ -z "${APP_HTML:-}" ]]; then
    # 取第一个 .html
    shopt -s nullglob
    htmls=("$BUILD_DIR"/*.html)
    if (( ${#htmls[@]} )); then
      APP_HTML="$(basename "${htmls[0]}")"
    else
      APP_HTML="app_revo_wallet.html"  # 最后兜底仅用于打印
    fi
  fi
fi

FULL_URL="http://${SERVE_HOST}:${PORT}/${APP_HTML}"
echo
echo "========== SERVE INFO =========="
echo "Serving directory : $BUILD_DIR"
echo "Entry HTML        : $APP_HTML"
echo "URL               : $FULL_URL"
echo "================================"
echo

# 6) 启动本地服务器
# - 单线程 wasm 可用任意静态服；多线程 wasm 建议 emrun（包含 COOP/COEP 头）
if [[ -n "${REVO_CI:-}" || "${CI:-}" == "true" ]]; then
    ls -lh "$BUILD_DIR" | sed -n '1,50p' || true
    exit 0
else
    if [[ -n "$EMSDK" && -x "$EMSDK/upstream/emscripten/emrun" ]]; then
      "$EMSDK/upstream/emscripten/emrun" --no_browser --port "$PORT" "$BUILD_DIR"
    else
      python3 -m http.server "$PORT" -d "$BUILD_DIR"
    fi
fi