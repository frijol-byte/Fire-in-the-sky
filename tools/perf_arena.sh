#!/usr/bin/env bash
# Flies the flight arena on a script for ~180 frames under Xvfb with Mesa's software Vulkan
# (lavapipe) and prints one line: average / p95 / worst frame time, draw calls and triangles.
#
#   bash tools/perf_arena.sh
#
# Informative only: a software renderer says nothing about a real GPU, but a big jump between
# two runs means something got heavier. The scene is game/tests/perf/arena_perf.tscn.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
cd "$ROOT" || exit 1

for tool in godot xvfb-run; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool not found: bash tools/cloud/setup.sh" >&2; exit 1; }
done
ICD=""
for f in /usr/share/vulkan/icd.d/lvp_icd*.json /etc/vulkan/icd.d/lvp_icd*.json; do
  [ -f "$f" ] && { ICD="$f"; break; }
done

godot --headless --path game --import >/dev/null 2>&1 || true
LOG="$(mktemp)"
env ${ICD:+VK_ICD_FILENAMES=$ICD VK_DRIVER_FILES=$ICD} \
  timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path game --audio-driver Dummy --resolution 1280x720 res://tests/perf/arena_perf.tscn >"$LOG" 2>&1
status=$?
grep -E '^PERF ' "$LOG" || { echo "no PERF line; log tail:" >&2; tail -n 25 "$LOG" >&2; status=1; }
grep -E '^(SCRIPT )?ERROR:' "$LOG" >&2 && status=1
rm -f "$LOG"
exit $status
