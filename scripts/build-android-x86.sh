#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

ANDROID_X86_DIR="${ANDROID_X86_DIR:-${PROJECT_DIR}/android-x86}"
ANDROID_X86_BRANCH="${ANDROID_X86_BRANCH:-jb-x86}"
TARGET_PRODUCT="${TARGET_PRODUCT:-android_x86}"
ARTIFACT_DIR="${ARTIFACT_DIR:-${PROJECT_DIR}/dist}"
REPO_SYNC_JOBS="${REPO_SYNC_JOBS:-2}"
BUILD_JOBS="${BUILD_JOBS:-2}"
MANIFEST_URL="${ANDROID_X86_MANIFEST_URL:-git://git.osdn.net/gitroot/android-x86/manifest}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

command -v repo >/dev/null 2>&1 || die "The repo launcher is not installed."
command -v make >/dev/null 2>&1 || die "make is not installed."
command -v java >/dev/null 2>&1 || die "Java is not installed."

mkdir -p "$ANDROID_X86_DIR" "$ARTIFACT_DIR"
cd "$ANDROID_X86_DIR"

echo "Android-x86 branch: $ANDROID_X86_BRANCH"
echo "Target product:     $TARGET_PRODUCT"
echo "Manifest URL:       $MANIFEST_URL"
echo "Repo sync jobs:     $REPO_SYNC_JOBS"
echo "Build jobs:         $BUILD_JOBS"
java -version

# The official Android-x86 instructions use the OSDN git:// manifest URL.
# Some CI networks block the git protocol, so retry with the documented
# HTTP mirror URL when using the default manifest.
if [[ ! -d .repo/manifests ]]; then
  if ! repo init -u "$MANIFEST_URL" -b "$ANDROID_X86_BRANCH"; then
    if [[ "$MANIFEST_URL" == "git://git.osdn.net/gitroot/android-x86/manifest" ]]; then
      echo "The git:// manifest endpoint failed; retrying via the documented HTTP endpoint."
      rm -rf .repo
      repo init -u "http://scm.osdn.net/gitroot/android-x86/manifest" -b "$ANDROID_X86_BRANCH" \
        || die "Could not initialize the Android-x86 manifest from either documented OSDN endpoint."
    else
      die "repo init failed for manifest URL: $MANIFEST_URL"
    fi
  fi
fi

# The Android-x86 project recommends retrying repo sync after transient
# network/server failures. Keep the attempts bounded for CI.
sync_ok=false
for attempt in 1 2 3; do
  echo "Synchronizing source tree (attempt $attempt/3)..."
  if repo sync --no-tags --no-clone-bundle --jobs="$REPO_SYNC_JOBS" --fail-fast; then
    sync_ok=true
    break
  fi
  if [[ "$attempt" -lt 3 ]]; then
    echo "repo sync failed; waiting briefly before retry."
    sleep 20
  fi
done
[[ "$sync_ok" == "true" ]] || die "repo sync failed after three attempts."

[[ -f build/core/main.mk ]] || die "The synced tree does not look like an Android source tree (build/core/main.mk missing)."

echo "Starting ISO build..."
make -j"$BUILD_JOBS" iso_img TARGET_PRODUCT="$TARGET_PRODUCT"

# Android-x86's Jelly Bean target normally produces android_x86.iso beneath
# out/target/product/x86. Search by product name first, then accept an ISO
# elsewhere in the product output tree for minor upstream layout differences.
ISO_FILE="$(find out/target/product -type f -name "${TARGET_PRODUCT}.iso" -size +0c -print -quit 2>/dev/null || true)"
if [[ -z "$ISO_FILE" ]]; then
  ISO_FILE="$(find out/target/product -type f -name '*.iso' -size +0c -print -quit 2>/dev/null || true)"
fi
[[ -n "$ISO_FILE" ]] || die "The build finished without producing an ISO under out/target/product."

OUTPUT_ISO="$ARTIFACT_DIR/android-x86-${ANDROID_X86_BRANCH}-${TARGET_PRODUCT}.iso"
mkdir -p "$ARTIFACT_DIR"
cp -- "$ISO_FILE" "$OUTPUT_ISO"

MANIFEST_REVISION="$(git -C .repo/manifests rev-parse HEAD 2>/dev/null || echo unknown)"
{
  echo "Android-x86 branch: $ANDROID_X86_BRANCH"
  echo "Target product: $TARGET_PRODUCT"
  echo "Manifest revision: $MANIFEST_REVISION"
  echo "Manifest URL: $MANIFEST_URL"
  echo "Source directory: $ANDROID_X86_DIR"
  echo "Built at (UTC): $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo "ISO: $(basename "$OUTPUT_ISO")"
  echo "ISO size (bytes): $(wc -c < "$OUTPUT_ISO" | tr -d ' ')"
} > "$ARTIFACT_DIR/build-info.txt"

echo "ISO ready: $OUTPUT_ISO"
ls -lh "$OUTPUT_ISO"
