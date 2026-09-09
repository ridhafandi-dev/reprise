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
