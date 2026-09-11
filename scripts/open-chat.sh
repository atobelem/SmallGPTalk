#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${SMALLGPTALK_BASE_IMAGE:?Set SMALLGPTALK_BASE_IMAGE to a clean Pharo 13 image.}"
vm="${SMALLGPTALK_VM:-$HOME/Documents/Pharo/vms/130-x64/Pharo.app/Contents/MacOS/Pharo}"
mkdir -p "$root/.build"
work="$(mktemp -d "$root/.build/chat-XXXXXX")"
cp "$SMALLGPTALK_BASE_IMAGE" "$work/SmallGPTalk.image"
cp "${SMALLGPTALK_BASE_IMAGE%.image}.changes" "$work/SmallGPTalk.changes"
for source in "$(dirname "$SMALLGPTALK_BASE_IMAGE")"/*.sources; do
  cp "$source" "$work/"
done
export SMALLGPTALK_ROOT="$root"
"$vm" --headless "$work/SmallGPTalk.image" st "$root/scripts/load.st"
exec "$vm" "$work/SmallGPTalk.image" st "$root/scripts/open-chat.st"
