#!/bin/bash
set -euo pipefail
export SMALLGPTALK_WORK_DIR="${SMALLGPTALK_WORK_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.build/keychain-check}"
export SMALLGPTALK_LOAD_GROUP=OpenAI
export SMALLGPTALK_KEYCHAIN_TEST_SERVICE="SmallGPTalk.Tests.$(uuidgen)"
source "$(dirname "$0")/common.sh"
bash "$SMALLGPTALK_ROOT/scripts/load.sh"
cd "$SMALLGPTALK_WORK_DIR"
smallgptalk_keychain_action() {
  SMALLGPTALK_KEYCHAIN_TEST_ACTION="$1" "$SMALLGPTALK_VM" --headless "$SMALLGPTALK_WORK_IMAGE" \
    st "$SMALLGPTALK_ROOT/scripts/keychain-check.st"
}
trap 'smallgptalk_keychain_action delete' EXIT
smallgptalk_keychain_action write
smallgptalk_keychain_action verify
