# Android PC — Android-x86 Jelly Bean

This repository provides the build configuration and GitHub Actions workflow for producing an Android-x86 **Jelly Bean (Android 4.3)** ISO.

The upstream Android-x86 source is a multi-repository tree managed by Google's `repo` tool. It is deliberately downloaded during the build instead of copied into this repository: the full source tree is very large and is maintained upstream.

## Build an ISO with GitHub Actions

1. Open the **Actions** tab.
2. Select **Build Android-x86 ISO (Jelly Bean)**.
3. Choose **Run workflow**. The defaults are:
   - Branch: `jb-x86`
   - Product: `android_x86` (32-bit x86)
4. Wait for the job to finish, then open the run and download the artifact named `android-x86-iso-<run number>`. It contains `android-x86-jb-x86-android_x86.iso` and `build-info.txt`.

The workflow also runs when build configuration files are changed on `main`.

## What the workflow does

- Creates an Ubuntu 18.04 build container with legacy Android build dependencies.
- Fetches the Android-x86 `jb-x86` manifest and source projects using `repo`.
- Builds `iso_img` for `TARGET_PRODUCT=android_x86`.
- Uploads the generated ISO and a small build-info file as a workflow artifact.

The expected source build output is under `out/target/product/`; the workflow collects the generated ISO into `dist/`.

## Upstream source and build notes

- Android-x86 source/build instructions: https://www.android-x86.org/source
- The upstream project identifies `jb-x86` as Android 4.3 Jelly Bean and documents `android_x86` as the target for Jelly Bean and KitKat.
- The upstream build documentation notes that older branches may require Oracle Java 6; it also lists OpenJDK 8 among the Ubuntu 18.04 build packages. This workflow uses OpenJDK 8 as the best-effort reproducible CI baseline. The branch is historical, so upstream toolchain changes or unavailable legacy dependencies can still cause a build failure.

## Source availability

This repository contains the project-specific build scripts and automation, not a vendored copy of every Android-x86/AOSP repository. The actual Android-x86 sources are fetched from the upstream manifest at build time. That keeps this repository manageable and avoids creating a stale fork of dozens of upstream repositories.

## Local build

The same build script is `scripts/build-android-x86.sh`. Run it in the provided container image after building the image:

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

The build downloads many gigabytes and can take several hours. A machine with substantial free disk space and RAM is recommended.
