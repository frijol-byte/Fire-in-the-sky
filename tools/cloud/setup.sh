#!/usr/bin/env bash
# Bootstraps a fresh cloud session: Godot, bpy venv, Xvfb, lint tools. Idempotent.
# Never fails because of a blocked download; it reports it in the summary instead.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
GODOT_VERSION="$(tr -d '[:space:]' < .godot-version)"
GODOT_DIR="$HOME/.local/godot"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$GODOT_DIR" "$BIN_DIR"
export PATH="$BIN_DIR:$PATH"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# 1. apt packages
APT_PKGS="xvfb mesa-vulkan-drivers libvulkan1 libgl1 libxi6 libxrandr2 libxcursor1 libxinerama1 unzip"
missing=""
for p in $APT_PKGS; do
  dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"
done
if [ -n "$missing" ]; then
  echo "== apt: installing:$missing"
  $SUDO apt-get update -qq || echo "apt-get update failed (continuing)"
  # shellcheck disable=SC2086
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y -qq $missing \
    || echo "apt-get install failed (continuing)"
else
  echo "== apt: all packages already installed"
fi

# 2. Godot
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
GODOT_BIN="$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64"
if [ ! -x "$GODOT_BIN" ]; then
  echo "== godot: downloading $GODOT_VERSION"
  tmp="$(mktemp -d)"
  if curl -fsSL --retry 3 -o "$tmp/godot.zip" "$GODOT_URL" \
     && unzip -qo "$tmp/godot.zip" -d "$GODOT_DIR" && [ -f "$GODOT_BIN" ]; then
    chmod +x "$GODOT_BIN"
  else
    echo "!! Godot download failed. The cloud environment's network policy probably blocks it."
    echo "!! Allowlist these hosts (see docs/06-ai-workflow.md section 2):"
    echo "!!   github.com  objects.githubusercontent.com  release-assets.githubusercontent.com"
    echo "!! Continuing without Godot; rely on CI for tests."
  fi
  rm -rf "$tmp"
fi
[ -x "$GODOT_BIN" ] && ln -sf "$GODOT_BIN" "$BIN_DIR/godot"

# 3. Blender (bpy) venv
VENV="tools/blender/.venv"
BPY_OK=0
if command -v uv >/dev/null 2>&1; then
  [ -x "$VENV/bin/python" ] || uv venv -q -p python3.13 "$VENV" || echo "uv venv failed"
  if [ -x "$VENV/bin/python" ]; then
    if uv pip install -q -p "$VENV/bin/python" -r tools/blender/requirements.txt; then BPY_OK=1; fi
  fi
else
  echo "!! uv not found; install it (https://docs.astral.sh/uv/) to build the bpy venv"
fi

# 4. gdtoolkit
GDT_OK=0
if pip install -q -r tools/requirements.txt 2>/dev/null \
   || pip install -q --break-system-packages -r tools/requirements.txt; then GDT_OK=1; fi
command -v gdformat >/dev/null 2>&1 || GDT_OK=0

# 5. Summary
ok() { if "$@" >/dev/null 2>&1; then echo "✅"; else echo "❌"; fi; }
echo
echo "================ setup summary ================"
printf '%-12s %s\n' "Godot" "$([ -x "$BIN_DIR/godot" ] && echo "✅ $GODOT_VERSION" || echo ❌)"
printf '%-12s %s\n' "bpy" "$([ "$BPY_OK" = 1 ] && "$VENV/bin/python" -c 'import bpy' >/dev/null 2>&1 && echo ✅ || echo ❌)"
printf '%-12s %s\n' "Xvfb" "$(command -v Xvfb >/dev/null 2>&1 && echo ✅ || echo ❌)"
printf '%-12s %s\n' "gdtoolkit" "$([ "$GDT_OK" = 1 ] && echo ✅ || echo ❌)"
echo "==============================================="
