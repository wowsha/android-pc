#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ANDROID_X86_DIR="${ANDROID_X86_DIR:-${PROJECT_DIR}/android-x86-build}"
ANDROID_X86_SOURCE_DIR="${ANDROID_X86_SOURCE_DIR:-${PROJECT_DIR}/android-x86-source}"
ANDROID_X86_BRANCH="${ANDROID_X86_BRANCH:-jb-x86}"
TARGET_PRODUCT="${TARGET_PRODUCT:-android_x86}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PROJECT_DIR}/dist}"
REPO_SYNC_JOBS="${REPO_SYNC_JOBS:-2}"
BUILD_JOBS="${BUILD_JOBS:-2}"
MANIFEST_URL="${ANDROID_X86_MANIFEST_URL:-https://github.com/android-x86-mirror/manifest}"

die() { echo "ERROR: $*" >&2; exit 1; }

command -v repo >/dev/null 2>&1 || die "The repo launcher is not installed."
command -v make >/dev/null 2>&1 || die "make is not installed."
command -v java >/dev/null 2>&1 || die "Java is not installed."
command -v rsync >/dev/null 2>&1 || die "rsync is not installed."
[[ -d "$ANDROID_X86_SOURCE_DIR" ]] || die "Vendored source directory missing: $ANDROID_X86_SOURCE_DIR"
[[ -f "$PROJECT_DIR/manifests/remove-jb-x86-projects.xml" ]] || die "Local manifest override is missing."

mkdir -p "$ANDROID_X86_DIR" "$ARTIFACT_DIR"
cd "$ANDROID_X86_DIR"

echo "Android-x86 branch: $ANDROID_X86_BRANCH"
echo "Target product:     $TARGET_PRODUCT"
echo "Manifest URL:       $MANIFEST_URL"
echo "Vendored source:    $ANDROID_X86_SOURCE_DIR"
java -version

if [[ ! -d .repo/manifests ]]; then
  repo init -u "$MANIFEST_URL" -b "$ANDROID_X86_BRANCH"
fi

# Android-x86-specific projects are committed in this repository.
# The local manifest removes them from Repo so only AOSP base projects sync.
mkdir -p .repo/local_manifests
cp "$PROJECT_DIR/manifests/remove-jb-x86-projects.xml" .repo/local_manifests/remove-jb-x86-projects.xml

sync_ok=false
for attempt in 1 2 3; do
  echo "Synchronizing AOSP base projects (attempt $attempt/3)..."
  if repo sync --no-tags --no-clone-bundle --jobs="$REPO_SYNC_JOBS" --fail-fast; then
    sync_ok=true
    break
  fi
  [[ "$attempt" -eq 3 ]] || { echo "Sync failed; retrying."; sleep 20; }
done
[[ "$sync_ok" == "true" ]] || die "AOSP base project sync failed after three attempts."

# Overlay checked-in Android-x86 code at the exact paths expected by the build.
rsync -a --exclude='README.md' --exclude='.source-imported/' "$ANDROID_X86_SOURCE_DIR/" "$ANDROID_X86_DIR/"

# The x86 build project's manifest copyfile is bypassed by the local
# remove-project overlay, so reproduce its root Makefile copy here.
[[ -f build/core/root.mk ]] || die "The vendored x86 build project is missing build/core/root.mk."
cp -f build/core/root.mk Makefile

[[ -f build/core/main.mk ]] || die "The assembled tree is missing build/core/main.mk."
[[ -f device/generic/x86/AndroidProducts.mk ]] || die "The vendored x86 device tree is missing."

echo "Starting ISO build..."
make -j"$BUILD_JOBS" iso_img TARGET_PRODUCT="$TARGET_PRODUCT"

ISO_FILE="$(find out/target/product -type f -name "${TARGET_PRODUCT}.iso" -size +0c -print -quit 2>/dev/null || true)"
if [[ -z "$ISO_FILE" ]]; then
  ISO_FILE="$(find out/target/product -type f -name '*.iso' -size +0c -print -quit 2>/dev/null || true)"
fi
[[ -n "$ISO_FILE" ]] || die "The build finished without producing an ISO under out/target/product."

OUTPUT_ISO="$ARTIFACT_DIR/android-x86-${ANDROID_X86_BRANCH}-${TARGET_PRODUCT}.iso"
cp -- "$ISO_FILE" "$OUTPUT_ISO"

{
  echo "Android-x86 branch: $ANDROID_X86_BRANCH"
  echo "Target product: $TARGET_PRODUCT"
  echo "Manifest URL: $MANIFEST_URL"
  echo "Vendored source directory: android-x86-source/"
  echo "Built at (UTC): $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "ISO: $(basename "$OUTPUT_ISO")"
  echo "ISO size (bytes): $(wc -c < "$OUTPUT_ISO" | tr -d ' ')"
} > "$ARTIFACT_DIR/build-info.txt"

echo "ISO ready: $OUTPUT_ISO"
ls -lh "$OUTPUT_ISO"
