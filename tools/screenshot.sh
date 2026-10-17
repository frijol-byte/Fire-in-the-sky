#!/usr/bin/env bash
# Renders Godot scenes to PNG under Xvfb with Mesa software Vulkan (lavapipe), using Movie
# Maker mode so capture is deterministic however slow the software renderer is.
#
#   tools/screenshot.sh <scene.tscn> [<scene.tscn> ...] [options]
#   tools/screenshot.sh --all [options]        every scene in game/tests/shots/
#
# A scene is a path relative to the repo root, to game/, or a res:// path (a bare name
# like `kestrel_shot` is looked up in game/tests/shots/). If it contains a
# ShotDirector (game/tests/shots/shot_director.gd), the frames it lists are kept as
# <out>_<label>.png. Otherwise the last of --frames N frames (default 30) is kept as <out>.png.
#
# Options:
#   --frames N        frames to run for scenes without a ShotDirector (default 30)
#   --out PREFIX      output path prefix (default build/screens/<scene name>); single scene only
#   --compat          force the OpenGL Compatibility renderer (PNGs get a COMPAT watermark)
#
# If Vulkan can't start (no usable GPU/ICD), it retries with the Compatibility renderer
# and watermarks every PNG "COMPAT". Compat renders are for layout checks only.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
SCREEN_DIR="build/screens"
FRAMES=30
OUT=""
FORCE_COMPAT=0
SCENES=()

usage() { sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --frames) FRAMES="${2:?--frames needs a number}"; shift 2 ;;
    --out) OUT="${2:?--out needs a path prefix}"; shift 2 ;;
    --compat) FORCE_COMPAT=1; shift ;;
    --all)
      while IFS= read -r f; do SCENES+=("$f"); done \
        < <(cd "$ROOT" && find game/tests/shots -name '*.tscn' | sort)
      shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) SCENES+=("$1"); shift ;;
  esac
done

if [ ${#SCENES[@]} -eq 0 ]; then usage >&2; exit 2; fi
if [ -n "$OUT" ] && [ ${#SCENES[@]} -gt 1 ]; then echo "--out works with one scene only" >&2; exit 2; fi
if ! command -v godot >/dev/null 2>&1; then
  echo "godot not found. Run: bash tools/cloud/setup.sh && export PATH=\$HOME/.local/bin:\$PATH" >&2
  exit 1
fi
if ! command -v xvfb-run >/dev/null 2>&1; then
  echo "xvfb-run not found. Run: bash tools/cloud/setup.sh" >&2
  exit 1
fi
PY=python3
if ! python3 -c 'import PIL' >/dev/null 2>&1 && [ -x "$ROOT/tools/blender/.venv/bin/python" ]; then
  PY="$ROOT/tools/blender/.venv/bin/python"
fi

cd "$ROOT" || exit 1
LVP_ICD="${SCREENSHOT_VK_ICD:-}"  # override (also used by the self-test)
for f in $([ -z "$LVP_ICD" ] && echo /usr/share/vulkan/icd.d/lvp_icd*.json /etc/vulkan/icd.d/lvp_icd*.json); do
  [ -f "$f" ] && { LVP_ICD="$f"; break; }
done
if [ ! -d game/.godot/imported ]; then
  echo "== importing project"
  godot --headless --path game --import >/dev/null 2>&1 || true
fi

# Resolves the scene argument to a res:// path, or prints nothing.
resolve_scene() {
  local s="$1"
  s="${s#res://}"; s="${s#./}"; s="${s#game/}"
  if [ -f "game/$s" ]; then echo "res://$s"
  elif [ -f "game/tests/shots/${s%.tscn}.tscn" ]; then echo "res://tests/shots/${s%.tscn}.tscn"; fi
}

# render_once <scene res path> <tmp dir> <mode: vulkan|compat> -> 0 on success.
# Leaves frames in <tmp>/movie*.png, the log in <tmp>/log.txt, any manifest in <tmp>/shots.json.
render_once() {
  local res="$1" tmp="$2" mode="$3" quit_after="$4"
  local args=(--path game --write-movie "$PWD/$tmp/movie.png" --fixed-fps 30
              --quit-after "$quit_after")
  local env_prefix=()
  if [ "$mode" = compat ]; then
    args+=(--rendering-method gl_compatibility --rendering-driver opengl3)
  elif [ -n "$LVP_ICD" ]; then
    env_prefix=(env "VK_ICD_FILENAMES=$LVP_ICD" "VK_DRIVER_FILES=$LVP_ICD")
  fi
  rm -f "$tmp"/movie*.png "$tmp/shots.json"
  timeout 600 xvfb-run -a -s "-screen 0 1920x1080x24" "${env_prefix[@]}" \
    godot "${args[@]}" "$res" -- "--shot-manifest=$PWD/$tmp/shots.json" \
    >"$tmp/log.txt" 2>&1
  local rc=$?
  ls "$tmp"/movie*.png >/dev/null 2>&1 || return 1
  [ $rc -eq 0 ] || return 1
  return 0
}

frame_file() { printf '%s/movie%08d.png' "$1" "$2"; }

# The frames the manifest lists, as "label frame" lines.
manifest_shots() {
  "$PY" -I - "$1" <<'PYEOF'
import json, sys
for s in json.load(open(sys.argv[1]))["shots"]:
    print(s["label"], s["frame"])
PYEOF
}

failed=0
for scene in "${SCENES[@]}"; do
  res="$(resolve_scene "$scene")"
  if [ -z "$res" ]; then echo "!! scene not found: $scene" >&2; failed=1; continue; fi
  name="$(basename "$res" .tscn)"
  prefix="${OUT:-$SCREEN_DIR/$name}"
  mkdir -p "$(dirname "$prefix")"
  tmp="build/screens/.tmp-$name"
  rm -rf "$tmp"; mkdir -p "$tmp"

  mode=vulkan; [ "$FORCE_COMPAT" = 1 ] && mode=compat
  # A ShotDirector quits the game itself; --quit-after is only the safety net for it.
  quit_after="$FRAMES"; grep -q 'shot_director.gd' "game/${res#res://}" && quit_after=600
  echo "== $res ($mode)"
  if ! render_once "$res" "$tmp" "$mode" "$quit_after"; then
    if [ "$mode" = vulkan ]; then
      echo "!! Vulkan render failed (see $tmp/log.txt); retrying with the Compatibility renderer"
      mode=compat
      render_once "$res" "$tmp" "$mode" "$quit_after" || true
    fi
  fi
  if ! ls "$tmp"/movie*.png >/dev/null 2>&1; then
    echo "!! no frames were rendered for $res. Log tail:" >&2
    tail -n 25 "$tmp/log.txt" >&2
    failed=1; continue
  fi
  # Godot may fall back to OpenGL by itself when Vulkan can't start, so trust its log.
  noise='^$'
  if grep -q 'OpenGL API' "$tmp/log.txt"; then
    if [ "$mode" = vulkan ]; then
      echo "!! Godot fell back to the Compatibility renderer on its own"
      noise='Vulkan|VK_|err != OK'  # the Vulkan start-up errors that caused the fallback
    fi
    mode=compat
  fi
  if grep -E '^(SCRIPT )?ERROR:' "$tmp/log.txt" | grep -Evq "$noise"; then
    echo "!! Godot reported errors for $res:" >&2
    grep -E '^(SCRIPT )?ERROR:' "$tmp/log.txt" | grep -Ev "$noise" >&2
    failed=1
  fi

  outputs=()
  if [ -s "$tmp/shots.json" ]; then
    while read -r label frame; do
      src="$(frame_file "$tmp" "$frame")"
      if [ ! -f "$src" ]; then echo "!! $res: frame $frame ($label) was not rendered" >&2; failed=1; continue; fi
      cp "$src" "${prefix}_${label}.png"; outputs+=("${prefix}_${label}.png")
    done < <(manifest_shots "$tmp/shots.json")
  else
    last="$(ls "$tmp"/movie*.png | sort | tail -n 1)"
    cp "$last" "$prefix.png"; outputs+=("$prefix.png")
  fi
  for png in "${outputs[@]}"; do
    [ "$mode" = compat ] && "$PY" -I tools/screenshot/imgtool.py watermark "$png" COMPAT
    echo "   -> $png"
  done
  rm -rf "$tmp"
done
exit $failed
