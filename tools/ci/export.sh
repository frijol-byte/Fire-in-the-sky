#!/usr/bin/env bash
# Writes game/version.txt, exports the Windows and Linux presets to build/export/, and proves the
# Linux build boots by running it headless for 120 frames. Used by ci.yml and release.yml; also
# runnable locally (needs Godot + export templates for the pinned version).
#
#   bash tools/ci/export.sh        version = git describe --tags --always
#   BUILD_VERSION=x bash ...       override the version string
#
# Output (PCK embedded): build/export/windows/FireInTheSky.exe, build/export/linux/FireInTheSky.x86_64
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"

VERSION="${BUILD_VERSION:-$(git describe --tags --always 2>/dev/null || echo dev)}"
printf '%s\n' "$VERSION" >game/version.txt
echo "== version: $VERSION"

rm -rf build/export
mkdir -p build/export/windows build/export/linux

echo "== import"
godot --headless --path game --import

export_preset() {
  local preset="$1" out="$2"
  echo "== export: $preset -> $out"
  godot --headless --path game --export-release "$preset" "$out" 2>&1 | tee "build/export/$(basename "$out").log"
  # Godot can print export errors and still exit 0, so check the output file and the log too.
  [ -s "build/${out#../build/}" ] || { echo "!! $out was not produced"; exit 1; }
  if grep -E '^(ERROR|SCRIPT ERROR):' "build/export/$(basename "$out").log"; then
    echo "!! $preset export logged errors"
    exit 1
  fi
}
export_preset "Windows Desktop" "../build/export/windows/FireInTheSky.exe"
export_preset "Linux" "../build/export/linux/FireInTheSky.x86_64"
chmod +x build/export/linux/FireInTheSky.x86_64

# Proxy for "the Windows build runs": boot the exported Linux build for 120 frames and require
# a clean exit, no engine errors, and the version string on screen's source (the boot log).
echo "== boot the exported Linux build for 120 frames"
BOOT_LOG="build/export/linux-boot.log"
set +e
build/export/linux/FireInTheSky.x86_64 --headless --quit-after 120 >"$BOOT_LOG" 2>&1
STATUS=$?
set -e
cat "$BOOT_LOG"
[ "$STATUS" -eq 0 ] || { echo "!! exported build exited with $STATUS"; exit 1; }
if grep -E '^(ERROR|SCRIPT ERROR|WARNING):' "$BOOT_LOG"; then
  echo "!! exported build logged errors or warnings"
  exit 1
fi
grep -qF "boot scene ready, version $VERSION" "$BOOT_LOG" \
  || { echo "!! exported build did not report version $VERSION"; exit 1; }
echo "== export OK ($VERSION)"
