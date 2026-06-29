#!/usr/bin/env bash
#
# export_sd15_coreml.sh — Task 0' (SD 1.5 Core ML export spike).
#
# Exports Stable Diffusion 1.5 to Core ML (.mlmodelc bundles + tokenizer assets)
# via Apple's `ml-stable-diffusion` torch2coreml converter, then side-loads the
# 6 resource artifacts FLAT into the app container at:
#
#     Application Support/Models/sd-1-5/<artifact>
#
# (NOT nested under Resources/ — CoreMLSpikeRunner resolves the flat layout.)
#
# All Python runs go through `uv` (never bare python3). Device transfer uses
# `xcrun devicectl`. See CLAUDE.md and design.md §10 (Task 0').
#
# Usage:
#   scripts/export_sd15_coreml.sh [options]

set -euo pipefail

# --- Defaults --------------------------------------------------------------

BUILD_DIR="build"
MODEL_VERSION="Lykon/dreamshaper-8"
BUNDLE_ID="com.retryai.bibleai"
DEVICE_UDID=""
HF_TOKEN="${HF_TOKEN:-}"
DRY_RUN=0
SKIP_PUSH=0
FORCE_PUSH=0

# The 6 artifacts CoreMLSpikeRunner.expectedResourceFiles requires. Kept in sync
# with BibleAI/BibleAI/AI/CoreMLSpikeRunner.swift.
RESOURCE_FILES=(
    "TextEncoder.mlmodelc"
    "Unet.mlmodelc"
    "VAEDecoder.mlmodelc"
    "VAEEncoder.mlmodelc"
    "vocab.json"
    "merges.txt"
)

# On-device destination, relative to the app's Application Support container.
DEVICE_SUBDIR="Library/Application Support/Models/sd-1-5"

# --- Helpers ---------------------------------------------------------------

usage() {
    cat <<EOF
Usage: export_sd15_coreml.sh [options]

Export Stable Diffusion 1.5 to Core ML and side-load it into the Bible AI app
container at "Application Support/${DEVICE_SUBDIR}/".

Options:
  --help                 Print this help and exit.
  --dry-run              Print every step that would run; do nothing real.
  --skip-push            Run the export but skip the device push.
  --build-dir DIR        Output directory (default: ${BUILD_DIR}).
  --device-udid UDID     Target a specific device; forces the push path.
  --force-push           Force the push path without a device-connected check.
  --model-version MODEL  HuggingFace model id (default: ${MODEL_VERSION}).
  --bundle-id BUNDLE     App bundle id (default: ${BUNDLE_ID}).
  --hf-token TOKEN       HuggingFace access token (also read from \$HF_TOKEN).
                         Not required for Lykon/dreamshaper-8 (public SD 1.5 fine-tune, no gate).
EOF
}

err() {
    echo "error: $*" >&2
}

# Echo a command in dry-run mode, or execute it for real otherwise.
run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

# Are all 6 resource artifacts already present under <build>/Resources/?
resources_present() {
    local res_dir="$1" f
    for f in "${RESOURCE_FILES[@]}"; do
        [[ -e "$res_dir/$f" ]] || return 1
    done
    return 0
}

# --- Argument parsing ------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --skip-push)
            SKIP_PUSH=1
            shift
            ;;
        --force-push)
            FORCE_PUSH=1
            shift
            ;;
        --build-dir)
            BUILD_DIR="${2:?--build-dir requires a value}"
            shift 2
            ;;
        --device-udid)
            DEVICE_UDID="${2:?--device-udid requires a value}"
            shift 2
            ;;
        --model-version)
            MODEL_VERSION="${2:?--model-version requires a value}"
            shift 2
            ;;
        --bundle-id)
            BUNDLE_ID="${2:?--bundle-id requires a value}"
            shift 2
            ;;
        --hf-token)
            HF_TOKEN="${2:?--hf-token requires a value}"
            shift 2
            ;;
        *)
            err "unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
done

# --- Dependency checks -----------------------------------------------------
# Run even in dry-run mode: a plan that can't be executed is not a valid plan,
# and the test harness asserts a missing dependency fails regardless of flags.

# Verify each tool is actually usable, not merely present on PATH. `command -v`
# alone would accept a broken install (e.g. a wrapper that exits non-zero).
# Probe with `--version` (which both tools support and which never names
# `devicectl`, so it can't be mistaken for a real push in the call logs).
if ! command -v uv > /dev/null 2>&1 || ! uv --version > /dev/null 2>&1; then
    err "'uv' not found or not usable on PATH. Install uv: https://docs.astral.sh/uv/"
    exit 1
fi

if ! command -v xcrun > /dev/null 2>&1 || ! xcrun --version > /dev/null 2>&1; then
    err "'xcrun' not found or not usable. Install Xcode (>= 15) and run 'xcode-select'."
    exit 1
fi

# --- Export phase ----------------------------------------------------------

# `--bundle-resources-for-swift-cli` writes its artifacts to <out>/Resources/.
# We point the converter at $BUILD_DIR/sd-1-5-coreml so the resources land at
# $BUILD_DIR/sd-1-5-coreml/Resources/ — the layout CoreMLSpikeRunner expects
# once flattened onto the device.
EXPORT_OUT="$BUILD_DIR/sd-1-5-coreml"
RES_DIR="$EXPORT_OUT/Resources"

if resources_present "$RES_DIR"; then
    echo "Resources already built, skipping export"
else
    echo "Exporting $MODEL_VERSION to Core ML at $EXPORT_OUT ..."
    run mkdir -p "$EXPORT_OUT"
    # Pin to Python 3.11: ml-stable-diffusion's transitive deps pin
    # tokenizers==0.19.1 (no wheel for 3.13+) and numpy==1.23.5 (no wheel for
    # 3.12+; distutils removed). 3.11 has pre-built wheels for both.
    run uv run \
        --python 3.11 \
        --with "git+https://github.com/apple/ml-stable-diffusion" \
        --with torch \
        --with "coremltools>=8.0" \
        --with diffusers \
        --with transformers \
        --with scipy \
        python3 -m python_coreml_stable_diffusion.torch2coreml \
        --model-version "$MODEL_VERSION" \
        --convert-text-encoder \
        --convert-unet \
        --convert-vae-decoder \
        --convert-vae-encoder \
        --attention-implementation SPLIT_EINSUM \
        --bundle-resources-for-swift-cli \
        -o "$EXPORT_OUT" \
        ${HF_TOKEN:+--hf-auth-token "$HF_TOKEN"}
fi

# --- Push decision ---------------------------------------------------------

if [[ "$SKIP_PUSH" -eq 1 ]]; then
    echo "Skipping device push (--skip-push)."
    exit 0
fi

# Determine whether to push. An explicit UDID or --force-push forces the push
# path with no connectivity probe. Otherwise, probe for a connected device and
# skip gracefully if none is present.
DEVICE_ARGS=()
if [[ -n "$DEVICE_UDID" ]]; then
    DEVICE_ARGS=(--device "$DEVICE_UDID")
elif [[ "$DRY_RUN" -eq 1 ]]; then
    : # dry-run: plan the push without a real device; skip UDID detection
else
    # Auto-detect the first connected physical device via devicectl JSON output.
    _tmp=$(mktemp)
    xcrun devicectl list devices --json-output "$_tmp" > /dev/null 2>&1 || true
    AUTO_UDID=$(uv run --quiet --python 3.11 python3 -c "
import json, sys
try:
    devs = json.load(open('$_tmp')).get('result', {}).get('devices', [])
    print(devs[0]['identifier']) if devs else sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null || true)
    rm -f "$_tmp"
    if [[ -z "$AUTO_UDID" ]]; then
        if [[ "$FORCE_PUSH" -eq 1 ]]; then
            err "--force-push requires a connected device or --device-udid."
            exit 1
        fi
        echo "No device connected and no --device-udid given; skipping push."
        exit 0
    fi
    echo "Auto-detected device: $AUTO_UDID"
    DEVICE_ARGS=(--device "$AUTO_UDID")
fi

# --- Push phase ------------------------------------------------------------
# Copy the entire local Resources/ tree to the container in ONE devicectl call.
# `devicectl device copy to` of a directory source recurses fully and creates
# intermediate destination directories, so copying <build>/.../Resources to
# "$DEVICE_SUBDIR" lands all 6 artifacts at $DEVICE_SUBDIR/<artifact> with the
# correct file/dir types (verified 2026-06-28).
#
# Do NOT decompose this into per-file copies: `copy to` with a FILE source whose
# destination is an existing directory *replaces that directory with the file*,
# which silently corrupts .mlmodelc bundles. A single directory copy avoids that.

echo "Pushing Resources/ tree to $BUNDLE_ID ($DEVICE_SUBDIR/) ..."
run xcrun devicectl device copy to \
    ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} \
    --domain-type appDataContainer \
    --domain-identifier "$BUNDLE_ID" \
    --source "$RES_DIR" \
    --destination "$DEVICE_SUBDIR"

echo "Done."
