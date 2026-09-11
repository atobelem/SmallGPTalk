#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${SMALLGPTALK_BASE_IMAGE:?Set SMALLGPTALK_BASE_IMAGE to a clean Pharo 13 image.}"
vm="${SMALLGPTALK_VM:-$HOME/Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo}"
runner=("$vm")
if command -v caffeinate >/dev/null 2>&1; then
  runner=(caffeinate -i "$vm")
fi
mkdir -p "$root/.build"
work="$(mktemp -d "$root/.build/test-XXXXXX")"
cp "$SMALLGPTALK_BASE_IMAGE" "$work/SmallGPTalk.image"
cp "${SMALLGPTALK_BASE_IMAGE%.image}.changes" "$work/SmallGPTalk.changes"
for source in "$(dirname "$SMALLGPTALK_BASE_IMAGE")"/*.sources; do
  cp "$source" "$work/"
done
export SMALLGPTALK_ROOT="$root"
"${runner[@]}" --headless "$work/SmallGPTalk.image" st "$root/scripts/load.st"
if [[ -n "${SMALLGPTALK_TEST_IMAGE_FILE:-}" ]]; then
  printf '%s\n' "$work/SmallGPTalk.image" > "$SMALLGPTALK_TEST_IMAGE_FILE"
fi
cd "$work"
"${runner[@]}" --headless SmallGPTalk.image test --junit-xml-output --fail-on-failure 'SmallGPTalk-Tests'
