#!/bin/bash
set -euo pipefail

SMALLGPTALK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SMALLGPTALK_ROOT
SMALLGPTALK_VM="${SMALLGPTALK_VM:-$HOME/Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo}"
SMALLGPTALK_BASE_DIR="${SMALLGPTALK_BASE_DIR:-$SMALLGPTALK_ROOT/.build/base}"
SMALLGPTALK_WORK_DIR="${SMALLGPTALK_WORK_DIR:-$SMALLGPTALK_ROOT/.build/test}"
[[ "$SMALLGPTALK_VM" = /* ]] || SMALLGPTALK_VM="$PWD/$SMALLGPTALK_VM"
[[ "$SMALLGPTALK_BASE_DIR" = /* ]] || SMALLGPTALK_BASE_DIR="$PWD/$SMALLGPTALK_BASE_DIR"
[[ "$SMALLGPTALK_WORK_DIR" = /* ]] || SMALLGPTALK_WORK_DIR="$PWD/$SMALLGPTALK_WORK_DIR"
SMALLGPTALK_WORK_IMAGE="$SMALLGPTALK_WORK_DIR/SmallGPTalk.image"

if [[ ! -x "$SMALLGPTALK_VM" ]]; then
  echo 'Set SMALLGPTALK_VM to the executable of a Pharo 13 VM.' >&2
  exit 1
fi

smallgptalk_prepare_image() {
  local archive base_image source_file base_changes
  mkdir -p "$SMALLGPTALK_BASE_DIR" "$SMALLGPTALK_WORK_DIR"
  if ! compgen -G "$SMALLGPTALK_BASE_DIR/*.image" > /dev/null; then
    archive="${SMALLGPTALK_IMAGE_ARCHIVE:-/Applications/PharoLauncher.app/Contents/Resources/images/pharo-stable.zip}"
    if [[ ! -f "$archive" ]]; then
      echo 'Set SMALLGPTALK_IMAGE_ARCHIVE to a clean Pharo 13 image ZIP.' >&2
      exit 1
    fi
    unzip -q "$archive" -d "$SMALLGPTALK_BASE_DIR"
  fi
  base_image="$(compgen -G "$SMALLGPTALK_BASE_DIR/*.image" | head -n 1)"
  cp "$base_image" "$SMALLGPTALK_WORK_IMAGE"
  base_changes="${base_image%.image}.changes"
  if [[ -f "$base_changes" ]]; then
    cp "$base_changes" "$SMALLGPTALK_WORK_DIR/SmallGPTalk.changes"
  else
    : > "$SMALLGPTALK_WORK_DIR/SmallGPTalk.changes"
  fi
  for source_file in "$SMALLGPTALK_BASE_DIR"/*.sources; do
    [[ -f "$source_file" ]] || continue
    ln -sf "$source_file" "$SMALLGPTALK_WORK_DIR/$(basename "$source_file")"
  done
}
