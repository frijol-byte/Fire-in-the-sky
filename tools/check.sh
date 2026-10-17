#!/usr/bin/env bash
# Runs every local gate: format, lint, data validation, Python tests, Blender pipeline tests,
# gdUnit4 (unit + sim) and the smoke test. Prints a PASS/FAIL table; exits non-zero on failure.
#
#   bash tools/check.sh           everything
#   bash tools/check.sh --quick   skips the long sims (game/tests/sim/long) and the
#                                 screenshot harness self-test
#
# Per-step logs go to build/check-logs/. Needs Godot on PATH (bash tools/cloud/setup.sh, then
# export PATH=$HOME/.local/bin:$PATH).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.local/bin:$PATH"

QUICK=0
for arg in "$@"; do
  case "$arg" in
    --quick) QUICK=1 ;;
    -h | --help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

LOGS="$ROOT/build/check-logs"
REPORTS="$ROOT/build/reports"
rm -rf "$LOGS" "$REPORTS"
mkdir -p "$LOGS" "$REPORTS"

NAMES=()
RESULTS=()
SECONDS_TAKEN=()
FAILED=0

# run_step <name> <command...>: runs the command, logs it, records PASS/FAIL/SKIP.
run_step() {
  local name="$1"
  shift
  local log="$LOGS/${name// /_}.log"
  local start=$SECONDS
  local status=0
  "$@" >"$log" 2>&1 || status=$?
  local took=$((SECONDS - start))
  NAMES+=("$name")
  SECONDS_TAKEN+=("$took")
  if [ "$status" -eq 0 ]; then
    RESULTS+=("PASS")
  else
    RESULTS+=("FAIL")
    FAILED=1
    echo "---- $name FAILED (exit $status). Last lines of $log:"
    sed 's/\x1b\[[0-9;]*m//g' "$log" | tail -n 40
    echo "----"
  fi
}

skip_step() {
  NAMES+=("$1")
  RESULTS+=("SKIP")
  SECONDS_TAKEN+=("0")
  echo "SKIP $1: $2"
}

# --- Python / GDScript sources -------------------------------------------------------------
mapfile -t GD_FILES < <(find game -name '*.gd' -not -path 'game/addons/*' -not -path 'game/.godot/*' | sort)

step_gdformat() { gdformat --check "${GD_FILES[@]}"; }
step_gdlint() { gdlint "${GD_FILES[@]}"; }
step_validate() { python3 tools/validate_data.py; }
step_tools_tests() { python3 -m unittest discover -s tools/tests; }
step_blender_tests() {
  tools/blender/.venv/bin/python -m unittest discover -s tools/blender/tests -t tools/blender
}

if command -v gdformat >/dev/null && command -v gdlint >/dev/null; then
  run_step "gdformat" step_gdformat
  run_step "gdlint" step_gdlint
else
  echo "gdtoolkit not installed: run bash tools/cloud/setup.sh (or pip install -r tools/requirements.txt)"
  NAMES+=("gdformat" "gdlint")
  RESULTS+=("FAIL" "FAIL")
  SECONDS_TAKEN+=("0" "0")
  FAILED=1
fi
run_step "validate_data" step_validate
run_step "tools tests" step_tools_tests
if [ -x tools/blender/.venv/bin/python ]; then
  run_step "blender tests" step_blender_tests
else
  skip_step "blender tests" "no tools/blender/.venv (run bash tools/cloud/setup.sh)"
fi

# --- Godot ---------------------------------------------------------------------------------
GODOT="$(command -v godot || true)"
if [ -z "$GODOT" ]; then
  echo "Godot not found on PATH. Run bash tools/cloud/setup.sh and export PATH=\$HOME/.local/bin:\$PATH."
  echo "If Godot can't be installed here, say so in the PR and rely on CI."
  NAMES+=("godot import" "gdunit unit" "gdunit sim" "smoke")
  RESULTS+=("FAIL" "FAIL" "FAIL" "FAIL")
  SECONDS_TAKEN+=("0" "0" "0" "0")
  FAILED=1
else
  step_import() {
    # Populates the global class cache and imports assets; the editor-less run exits 0 on success.
    "$GODOT" --headless --path game --import
  }

  # gdUnit4 exits 0 only if every test passed with no warnings (e.g. orphan nodes).
  gdunit() {
    local target_args=()
    for target in "$@"; do target_args+=(-a "$target"); done
    "$GODOT" --headless --path game -s -d --remote-debug tcp://127.0.0.1:0 \
      res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c \
      -rd ../build/reports -rc 1 "${target_args[@]}"
  }
  step_unit() { gdunit res://tests/unit; }
  step_sim() {
    local targets=()
    while IFS= read -r file; do targets+=("res://${file#game/}"); done \
      < <(find game/tests/sim -maxdepth 1 -name 'test_*.gd' | sort)
    if [ "$QUICK" -eq 0 ]; then targets+=(res://tests/sim/long); fi
    gdunit "${targets[@]}"
  }
  step_smoke() {
    local log="$LOGS/smoke_engine.log"
    "$GODOT" --headless --path game -s res://tests/smoke/smoke_runner.gd >"$log" 2>&1
    local status=$?
    cat "$log"
    # Backstop: anything the engine logged as an error/warning fails the run, even when the
    # in-engine log catcher missed it (e.g. parse errors while loading autoloads).
    if grep -E '^(SCRIPT ERROR|ERROR|WARNING):' "$log"; then status=1; fi
    return "$status"
  }
  # Renders real frames under Xvfb + lavapipe (tools/screenshot.sh), so it needs Xvfb.
  step_screenshots() { bash tools/tests/screenshot_test.sh; }

  run_step "godot import" step_import
  run_step "gdunit unit" step_unit
  run_step "gdunit sim" step_sim
  run_step "smoke" step_smoke
  if [ "$QUICK" -eq 1 ]; then
    skip_step "screenshots" "--quick skips the screenshot harness self-test"
  elif command -v xvfb-run >/dev/null; then
    run_step "screenshots" step_screenshots
  else
    echo "xvfb-run not found: run bash tools/cloud/setup.sh"
    NAMES+=("screenshots")
    RESULTS+=("FAIL")
    SECONDS_TAKEN+=("0")
    FAILED=1
  fi
fi

# --- Summary -------------------------------------------------------------------------------
echo
echo "================ check.sh summary ================"
printf '%-16s %-6s %s\n' "STEP" "RESULT" "SECONDS"
for i in "${!NAMES[@]}"; do
  printf '%-16s %-6s %s\n' "${NAMES[$i]}" "${RESULTS[$i]}" "${SECONDS_TAKEN[$i]}"
done
echo "=================================================="
if [ "$FAILED" -eq 0 ]; then
  echo "ALL CHECKS PASSED"
else
  echo "CHECKS FAILED (logs in build/check-logs/)"
fi
exit "$FAILED"
