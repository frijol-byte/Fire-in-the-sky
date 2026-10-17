#!/usr/bin/env bash
# Self-test for tools/screenshot.sh. Needs Godot + Xvfb (see tools/cloud/setup.sh).
# Checks: a plain scene renders a non-blank PNG; a ShotDirector scene keeps exactly its
# labelled frames and they differ from each other; the Compatibility fallback (forced, and
# automatic when Vulkan can't start) stamps COMPAT; a bad scene name fails.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
export PATH="$HOME/.local/bin:$PATH"
PY=python3
python3 -c 'import PIL' >/dev/null 2>&1 || PY="$ROOT/tools/blender/.venv/bin/python"
IMG="$PY -I tools/screenshot/imgtool.py"
OUT="build/screens-test"
rm -rf "$OUT"; mkdir -p "$OUT"
fails=0
check() { if "${@:2}" >/dev/null 2>&1; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
nonblank() { [ "$($IMG stats "$1" | sed 's/.*distinct=//')" -gt 8 ]; }
differs() { $IMG differs "$1" "$2"; }
is_stamped() { [ "$($IMG diff "$1" "$2")" != "0.0000" ]; }

check "plain scene renders" bash tools/screenshot.sh core/boot/boot.tscn --frames 4 --out "$OUT/plain"
check "plain scene PNG is not blank" nonblank "$OUT/plain.png"
check "plain scene is 1920x1080" test "$($IMG stats "$OUT/plain.png" | cut -d' ' -f1)" = 1920x1080

check "shot scene renders" bash tools/screenshot.sh kestrel_shot --out "$OUT/k"
check "exactly the three labelled shots exist" test "$(ls "$OUT" | grep -c '^k_')" = 3
check "shots are not blank" nonblank "$OUT/k_top.png"
check "three_quarter differs from top" differs "$OUT/k_three_quarter.png" "$OUT/k_top.png"
check "top differs from front" differs "$OUT/k_top.png" "$OUT/k_front.png"
check "temp frames are cleaned up" test -z "$(ls -A build/screens | grep '^\.tmp-')"

check "forced compat renders" bash tools/screenshot.sh boot_shot --compat --out "$OUT/compat"
check "compat PNG is watermarked" is_stamped "$OUT/compat_boot.png" "$OUT/plain.png"
check "automatic fallback renders" env SCREENSHOT_VK_ICD=/nonexistent.json bash tools/screenshot.sh boot_shot --out "$OUT/auto"
check "automatic fallback PNG is watermarked" is_stamped "$OUT/auto_boot.png" "$OUT/plain.png"

check "bad scene fails" bash -c '! bash tools/screenshot.sh no_such_scene.tscn'
echo
[ "$fails" = 0 ] && echo "screenshot_test: all passed" || { echo "screenshot_test: $fails failed"; exit 1; }
