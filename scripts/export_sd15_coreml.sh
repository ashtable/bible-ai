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
MODEL_VERSION="CompVis/stable-diffusion-v1-5"
BUNDLE_ID="com.retryai.bibleai"
DEVICE_UDID=""
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
DEVICE_SUBDIR="Models/sd-1-5"

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
    run uv run \
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
        -o "$EXPORT_OUT"
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
elif [[ "$FORCE_PUSH" -eq 1 ]]; then
    : # push to the default device with no UDID
elif [[ "$DRY_RUN" -eq 1 ]]; then
    : # dry-run plans the push without requiring a real device
else
    if ! xcrun devicectl list devices > /dev/null 2>&1; then
        echo "No device connected and no --device-udid/--force-push given; skipping push."
        exit 0
    fi
fi

# --- Push phase ------------------------------------------------------------
# Flatten <build>/Resources/<artifact> -> container Application Support/Models/sd-1-5/<artifact>.
# The destination must NOT carry the Resources/ subdirectory through to the device.

echo "Pushing ${#RESOURCE_FILES[@]} artifacts to $BUNDLE_ID (Application Support/$DEVICE_SUBDIR/) ..."
for f in "${RESOURCE_FILES[@]}"; do
    src="$RES_DIR/$f"
    dest="$DEVICE_SUBDIR/$f"
    run xcrun devicectl device copy to \
        ${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"} \
        --domain-type appDataContainer \
        --domain-identifier "$BUNDLE_ID" \
        --source "$src" \
        --destination "$dest"
done

echo "Done."
