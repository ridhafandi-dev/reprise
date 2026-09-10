#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
REPRISE_TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reprise-tests.XXXXXX")"
trap 'rm -rf "$REPRISE_TEST_DIR"' EXIT
swiftc -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" Reprise/Capture.swift Reprise/Thread.swift Reprise/Tests.swift -o "$REPRISE_TEST_DIR/model"
"$REPRISE_TEST_DIR/model"
swiftc -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" Reprise/Capture.swift Reprise/Thread.swift Reprise/Store.swift Reprise/NotchSupport.swift Reprise/HoverTests.swift -o "$REPRISE_TEST_DIR/hover"
"$REPRISE_TEST_DIR/hover"

swiftc -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" Reprise/Capture.swift Reprise/Thread.swift Reprise/Store.swift Reprise/NotchSupport.swift Reprise/CaptureTests.swift -o "$REPRISE_TEST_DIR/capture"
"$REPRISE_TEST_DIR/capture"
node Reprise/Extension/tests.cjs

# Gate tests never use the installed application's data directory.
export REPRISE_GATE_PATH="$REPRISE_TEST_DIR/gate-inbox"
swiftc -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" \
  Reprise/GateModels.swift Reprise/GateStore.swift Reprise/GateTests.swift -o "$REPRISE_TEST_DIR/gate-tests"
"$REPRISE_TEST_DIR/gate-tests"
swiftc -parse-as-library -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" \
  Reprise/GateModels.swift Reprise/GateStore.swift Reprise/GateCLI.swift -o "$REPRISE_TEST_DIR/RepriseGate"
python3 Reprise/GateCLITests.py "$REPRISE_TEST_DIR/RepriseGate"

swiftc -module-cache-path "${TMPDIR:-/tmp}/reprise-swift-module-cache" \
  Reprise/GateModels.swift Reprise/GateStore.swift Reprise/GateSession.swift Reprise/GateSessionTests.swift \
  -o "$REPRISE_TEST_DIR/gate-session-tests"
"$REPRISE_TEST_DIR/gate-session-tests"
