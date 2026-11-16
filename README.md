# Android PC — Android-x86 Jelly Bean

This project builds a 32-bit Android-x86 Jelly Bean (Android 4.3) ISO.

## Source layout

The Android-x86-specific source projects are stored in this repository under
`android-x86-source/`. The pinned source list is in
`manifests/jb-x86-vendor.tsv`; every imported project keeps its upstream
license, copyright and NOTICE files. The sources come from the public
[Android-x86 GitHub mirror](https://github.com/android-x86-mirror).

Android 4.3 is a multi-repository AOSP release. This repository vendors the
42 Android-x86-specific projects; the unmodified AOSP base projects remain
external upstream dependencies and are synchronized when the build runs.
The complete historical AOSP checkout is much larger than a normal application
repository, so this repo contains the Android-x86-specific source overlay.

## Import source

The **Import Android-x86 Jelly Bean source** workflow imports the pinned
Android-x86 project sources into `android-x86-source/` and commits them to
this repository one project at a time. It is a one-time source import; normal
ISO builds do not download those 42 Android-x86 projects again.

The importer can be run from the Actions tab if it needs to be resumed. Already
imported projects are identified by commit markers and skipped on a retry.

## Build an ISO

After the source import succeeds:

1. Open **Actions**.
2. Select **Build Android-x86 ISO (Jelly Bean)**.
3. Select **Run workflow** (defaults to `android_x86`).
4. Download the ISO from the completed run's **Artifacts** section.

The source-import workflow also starts an ISO build automatically after it
finishes successfully.

## Build configuration

- Android-x86 branch: `jb-x86`
- Android target: `android_x86` (32-bit x86)
- Build container: Ubuntu 18.04 with OpenJDK 8 and legacy build dependencies
- ISO target: `make iso_img TARGET_PRODUCT=android_x86`

Jelly Bean is a historical Android release. Its upstream documentation says
pre-KitKat branches may require Oracle Java 6 and warns that OpenJDK may not
work. The CI toolchain uses OpenJDK 8 as a best-effort baseline, so a successful
source import does not guarantee a successful ISO build; compiler/toolchain
compatibility may still need follow-up fixes.

## Local build

Build and run the container as documented below after the source is present:

```sh
docker build -f docker/android-x86-builder.Dockerfile -t android-x86-builder .
mkdir -p dist
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  -e HOME=/tmp/android-home \
  -e ANDROID_X86_BRANCH=jb-x86 \
  -e TARGET_PRODUCT=android_x86 \
  -e ARTIFACT_DIR=/workspace/dist \
  android-x86-builder \
  bash -lc 'mkdir -p "$HOME" && bash scripts/build-android-x86.sh'
```
