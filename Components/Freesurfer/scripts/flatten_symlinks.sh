#!/bin/bash
# flatten_symlinks.sh
# Usage: ./flatten_symlinks.sh <target_directory>

target_dir=$1
cd "$target_dir"

find . -type l | while read symlink; do
  target=$(readlink -f "$symlink")
  echo "[Flattening] $symlink → $target"

  if [ -d "$target" ]; then
    echo "[SKIPPED] $symlink points to a directory ($target)"
    continue
  fi

  rm -f "$symlink"
  cp "$target" "$symlink"
done