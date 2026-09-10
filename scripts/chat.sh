#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
export SMALLGPTALK_WORK_DIR
SMALLGPTALK_WORK_DIR="$(mktemp -d "$SMALLGPTALK_ROOT/.build/chat-XXXXXX")"
export SMALLGPTALK_LOAD_GROUP=Chat
bash "$SMALLGPTALK_ROOT/scripts/load.sh"
open -n -a "$(dirname "$(dirname "$(dirname "$SMALLGPTALK_VM")")")" --args \
  "$SMALLGPTALK_WORK_DIR/SmallGPTalk.image" st "$SMALLGPTALK_ROOT/examples/chat.st"
