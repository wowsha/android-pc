# Vendored Android-x86 Jelly Bean source

This directory contains Android-x86-specific project source imported from the public
[android-x86-mirror](https://github.com/android-x86-mirror) repositories at the
branches recorded in `../../manifests/jb-x86-vendor.tsv`.

The import preserves each upstream project's own license, copyright, and NOTICE files.
It is not the complete AOSP source tree: unmodified Android 4.3 base projects remain
external AOSP dependencies and are synchronized from the Android source servers during
the build. The checked-in overlay is what makes this repository-specific Android-x86
code available without fetching those 41 projects during every CI run.
