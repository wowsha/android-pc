#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(git rev-parse --show-toplevel)"
MAP="$ROOT/manifests/jb-x86-vendor.tsv"
VENDOR_ROOT="$ROOT/android-x86-source"
MARKER_DIR="$VENDOR_ROOT/.source-imported"
MAX_PROJECT_MIB="${MAX_PROJECT_MIB:-1700}"

[[ -f "$MAP" ]] || { echo "Missing source map: $MAP" >&2; exit 1; }
mkdir -p "$VENDOR_ROOT" "$MARKER_DIR"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

while IFS=$'\t' read -r target_path upstream_repo upstream_branch; do
  [[ -z "${target_path:-}" || "$target_path" == \#* ]] && continue
  [[ -n "${upstream_repo:-}" && -n "${upstream_branch:-}" ]] || {
    echo "Malformed source map row: $target_path $upstream_repo $upstream_branch" >&2
    exit 1
  }

  marker="$MARKER_DIR/${upstream_repo}.txt"
  destination="$VENDOR_ROOT/$target_path"

  if [[ -f "$marker" ]]; then
    echo "Already imported: $target_path ($upstream_repo)"
    continue
  fi

  echo "::group::Import $target_path from android-x86-mirror/$upstream_repo@$upstream_branch"
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "$temp_dir"' EXIT

  git clone --quiet --depth=1 --single-branch --branch "$upstream_branch" \
    "https://github.com/android-x86-mirror/$upstream_repo.git" "$temp_dir/repo"

  upstream_commit="$(git -C "$temp_dir/repo" rev-parse HEAD)"
  rm -rf "$temp_dir/repo/.git"

  rm -rf "$destination"
  mkdir -p "$(dirname "$destination")"
  cp -a "$temp_dir/repo" "$destination"

  size_mib="$(du -sm "$destination" | awk '{print $1}')"
  if (( size_mib > MAX_PROJECT_MIB )); then
    echo "Project $target_path is ${size_mib} MiB; refusing an oversized single-project push." >&2
    exit 1
  fi

  oversized="$(find "$destination" -type f -size +99M -print || true)"
  if [[ -n "$oversized" ]]; then
    echo "Files exceed GitHub's 100 MiB regular-Git limit in $target_path:" >&2
    echo "$oversized" >&2
    exit 1
  fi

  printf 'repository=https://github.com/android-x86-mirror/%s\nbranch=%s\ncommit=%s\n' \
    "$upstream_repo" "$upstream_branch" "$upstream_commit" > "$marker"

  git add -- "$destination" "$marker"
  git commit -m "Vendor Android-x86 Jelly Bean: $target_path"

  # A maintainer edit can land on main while this long import is running.
  # Rebase this project's commit onto the new main head and retry the push.
  pushed=false
  for attempt in 1 2 3; do
    if git push origin "HEAD:refs/heads/main"; then
      pushed=true
      break
    fi
    echo "Push was rejected; fetching main and rebasing (attempt $attempt/3)..."
    git fetch origin main
    git rebase origin/main
  done
  [[ "$pushed" == "true" ]] || {
    echo "Could not push imported project $target_path after three attempts." >&2
    exit 1
  }

  echo "Imported $target_path (${size_mib} MiB, $upstream_commit)"
  rm -rf "$temp_dir"
  trap - EXIT
  # Stay below GitHub's recommended push rate.
  sleep 11
  echo "::endgroup::"
done < "$MAP"

echo "All Android-x86 Jelly Bean overlay projects are present in $VENDOR_ROOT."
