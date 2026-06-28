#!/usr/bin/env bash
#
# Test harness for scripts/export_sd15_coreml.sh (Task 0' — SD 1.5 Core ML export spike).
#
# The script under test does NOT exist yet. Every behavioral test below is expected
# to FAIL until scripts/export_sd15_coreml.sh is written. That is by design: this is
# the red phase of the TDD loop.
#
# Run from the repo root:  bash scripts/test_export_script.sh
#
# Design notes:
#   - `uv` and `xcrun` are stubbed onto PATH so no real export, model download, or
#     device is needed. The stubs record their argv to /tmp/{uv,xcrun}_calls.txt so
#     tests can assert on how the script invoked them.
#   - The script-under-test contract these tests pin down:
#       * --dry-run            : validate + plan only, exit 0, no device required
#       * --help               : print usage (contains "Usage"), exit 0
#       * --skip-push          : run export but never call `xcrun devicectl`
#       * --device-udid <id>   : force the push path without a real-device check
#       * --force-push         : (accepted alias) force the push path
#       * --model-version <id> : override the default HF model passed to the export
#       * missing `uv`/`xcrun`  : exit non-zero with a clear failure
#       * pre-built build/sd-1-5-coreml/Resources/ with all 6 artifacts → skip export
#       * push flattens Resources/ → device receives sd-1-5/<artifact>, not
#         sd-1-5/Resources/<artifact>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/export_sd15_coreml.sh"
PASS=0
FAIL=0

UV_CALLS="/tmp/uv_calls.txt"
XCRUN_CALLS="/tmp/xcrun_calls.txt"

# Temp dirs created during the run; cleaned up on exit.
TMP_DIRS=()

cleanup() {
    local d
    for d in "${TMP_DIRS[@]:-}"; do
        [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
    done
    rm -f "$UV_CALLS" "$XCRUN_CALLS"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    shift
    if "$@"; then
        echo "PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $name"
        FAIL=$((FAIL + 1))
    fi
}

# Create a temp dir with fake `uv` and `xcrun` binaries. Echoes the dir path.
# Both stubs exit 0 and append their argv to the shared call-log files so tests
# can assert on invocation arguments.
setup_stubs() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    TMP_DIRS+=("$tmpdir")

    cat > "$tmpdir/uv" <<'EOF'
#!/usr/bin/env bash
echo "uv called: $*" >> /tmp/uv_calls.txt
exit 0
EOF
    chmod +x "$tmpdir/uv"

    cat > "$tmpdir/xcrun" <<'EOF'
#!/usr/bin/env bash
echo "xcrun called: $*" >> /tmp/xcrun_calls.txt
exit 0
EOF
    chmod +x "$tmpdir/xcrun"

    echo "$tmpdir"
}

# Create a temp dir holding only the named stub binaries (used for the
# missing-dependency tests). Args: list of binary names ("uv", "xcrun").
setup_partial_stubs() {
    local tmpdir bin
    tmpdir="$(mktemp -d)"
    TMP_DIRS+=("$tmpdir")
    for bin in "$@"; do
        cat > "$tmpdir/$bin" <<EOF
#!/usr/bin/env bash
echo "$bin called: \$*" >> /tmp/${bin}_calls.txt
exit 0
EOF
        chmod +x "$tmpdir/$bin"
    done
    echo "$tmpdir"
}

# Populate <build>/sd-1-5-coreml/Resources/ with the 6 artifacts the script
# treats as a complete pre-built export, so the export phase can be skipped.
# Echoes the build dir path.
make_prebuilt_resources() {
    local builddir resdir
    builddir="$(mktemp -d)"
    TMP_DIRS+=("$builddir")
    resdir="$builddir/sd-1-5-coreml/Resources"
    mkdir -p "$resdir"
    # Compiled Core ML model bundles are directories (.mlmodelc); tokenizer
    # assets are plain files. Shape them accordingly.
    mkdir -p "$resdir/TextEncoder.mlmodelc" \
             "$resdir/Unet.mlmodelc" \
             "$resdir/VAEDecoder.mlmodelc" \
             "$resdir/VAEEncoder.mlmodelc"
    : > "$resdir/vocab.json"
    : > "$resdir/merges.txt"
    echo "$builddir"
}

# Clear the shared call logs before a test that asserts on them.
reset_call_logs() {
    : > "$UV_CALLS"
    : > "$XCRUN_CALLS"
}

# Guard for every behavioral test: the script must exist and be runnable.
# Without this, "absence" assertions (e.g. `! grep devicectl log`) and
# "exits non-zero" assertions trivially pass while the script is missing,
# producing false greens. This keeps the red phase honestly red.
require_script() {
    [[ -f "$SCRIPT" ]]
}

# --- Tests -----------------------------------------------------------------

# T1 — --dry-run exits 0.
test_dry_run_exits_zero() {
    local stubs
    stubs="$(setup_stubs)"
    PATH="$stubs:$PATH" bash "$SCRIPT" --dry-run --skip-push
}

# T2 — missing `uv` exits non-zero (PATH has xcrun but not uv).
test_missing_uv_fails() {
    require_script || return 1
    local stubs rc
    stubs="$(setup_partial_stubs xcrun)"
    rc=0
    # Use an empty-ish PATH plus the partial stub dir so `uv` cannot be found
    # via the real environment either. /usr/bin is kept for core utilities the
    # script may legitimately call (mkdir, grep, ...).
    PATH="$stubs:/usr/bin:/bin" bash "$SCRIPT" --dry-run --skip-push || rc=$?
    [[ "$rc" -ne 0 ]]
}

# T3 — missing `xcrun` exits non-zero (PATH has uv but not xcrun).
test_missing_xcrun_fails() {
    require_script || return 1
    local stubs rc
    stubs="$(setup_partial_stubs uv)"
    rc=0
    PATH="$stubs:/usr/bin:/bin" bash "$SCRIPT" --dry-run --skip-push || rc=$?
    [[ "$rc" -ne 0 ]]
}

# T4 — --help exits 0 and prints "Usage".
test_help_prints_usage() {
    bash "$SCRIPT" --help | grep -q "Usage"
}

# T5 — pre-built Resources/ skips the export phase (no torch2coreml via uv).
test_prebuilt_skips_export() {
    local stubs builddir
    require_script || return 1
    stubs="$(setup_stubs)"
    builddir="$(make_prebuilt_resources)"
    reset_call_logs
    # The run must succeed; only then is "export was skipped" meaningful.
    PATH="$stubs:$PATH" bash "$SCRIPT" --skip-push --build-dir "$builddir" || return 1
    # The export step shells out to the diffusers torch2coreml converter via uv.
    # If it ran, the call log would mention it.
    ! grep -q "torch2coreml" "$UV_CALLS"
}

# T6 — --skip-push prevents any `xcrun devicectl` call.
test_skip_push_no_devicectl() {
    local stubs builddir
    require_script || return 1
    stubs="$(setup_stubs)"
    builddir="$(make_prebuilt_resources)"
    reset_call_logs
    PATH="$stubs:$PATH" bash "$SCRIPT" --skip-push --build-dir "$builddir" || return 1
    ! grep -q "devicectl" "$XCRUN_CALLS"
}

# T7 — --dry-run exits 0 even with no device attached.
test_dry_run_no_device() {
    local stubs
    stubs="$(setup_stubs)"
    # No --device-udid, no --force-push: a dry run must not require a device.
    PATH="$stubs:$PATH" bash "$SCRIPT" --dry-run
}

# T8 — push uses the flat layout (sd-1-5/<artifact>), not nested Resources/.
test_push_flattens_resources() {
    require_script || return 1
    local stubs builddir
    stubs="$(setup_stubs)"
    builddir="$(make_prebuilt_resources)"
    reset_call_logs
    # --device-udid forces the push path without a real-device connectivity check.
    PATH="$stubs:$PATH" bash "$SCRIPT" \
        --build-dir "$builddir" \
        --device-udid fake-udid
    # Sanity: the push path must have actually run.
    grep -q "devicectl" "$XCRUN_CALLS" || return 1
    # Destination must be the flat layout...
    grep -q "sd-1-5/Unet.mlmodelc" "$XCRUN_CALLS" || return 1
    # ...and must NOT carry the Resources/ subdirectory through to the device.
    ! grep -q "sd-1-5/Resources/" "$XCRUN_CALLS"
}

# T9 — --model-version overrides the default model passed to the export.
test_model_version_override() {
    require_script || return 1
    local stubs builddir
    stubs="$(setup_stubs)"
    # Fresh build dir with NO pre-built Resources/, so the export phase runs and
    # the model id reaches `uv`.
    builddir="$(mktemp -d)"
    TMP_DIRS+=("$builddir")
    reset_call_logs
    PATH="$stubs:$PATH" bash "$SCRIPT" \
        --skip-push \
        --build-dir "$builddir" \
        --model-version custom/model
    grep -q "custom/model" "$UV_CALLS"
}

# T10 — shellcheck passes on both files (script under test + this harness).
# Skips cleanly if shellcheck is not installed; once the main script exists and
# shellcheck is available, this enforces a zero-warning, zero-error bar.
test_shellcheck_clean() {
    if ! command -v shellcheck > /dev/null 2>&1; then
        echo "  (shellcheck not installed — skipping lint; install via 'brew install shellcheck')"
        return 0
    fi
    # shellcheck is present: a missing script-under-test is a genuine failure
    # (the spec requires T10 to fail until the script exists and lints clean).
    require_script || return 1
    local f count
    for f in "$SCRIPT" "${BASH_SOURCE[0]}"; do
        # grep -c can exit non-zero (no matches) under set -e; guard with `|| true`.
        count="$(shellcheck "$f" 2>&1 | grep -c "warning\|error" || true)"
        if [[ "$count" -ne 0 ]]; then
            echo "  shellcheck reported $count warning/error line(s) in $f"
            return 1
        fi
    done
}

# --- Run -------------------------------------------------------------------

run_test "T1  --dry-run exits 0"                       test_dry_run_exits_zero
run_test "T2  missing uv exits non-zero"               test_missing_uv_fails
run_test "T3  missing xcrun exits non-zero"            test_missing_xcrun_fails
run_test "T4  --help prints Usage and exits 0"         test_help_prints_usage
run_test "T5  pre-built Resources/ skips export"       test_prebuilt_skips_export
run_test "T6  --skip-push blocks devicectl"            test_skip_push_no_devicectl
run_test "T7  --dry-run exits 0 with no device"        test_dry_run_no_device
run_test "T8  push flattens Resources/ layout"         test_push_flattens_resources
run_test "T9  --model-version overrides default"       test_model_version_override
run_test "T10 shellcheck clean on both files"          test_shellcheck_clean

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
