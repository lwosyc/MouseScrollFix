#!/usr/bin/env bash
#
# Runs the Core test suite.
#
# The suite is a plain executable rather than an XCTest/swift-testing target: the
# Command Line Tools ship no XCTest, and this toolchain's swift-testing integration
# emits an empty discovery section, so `swift test` cannot run anything here. On a
# machine with a full Xcode install, `swift build` and the app itself are unaffected.
#
set -euo pipefail

cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.modulecache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$PWD/.modulecache}"
export TMPDIR="${TMPDIR:-$PWD/.tmp}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$TMPDIR"

exec swift run --disable-sandbox MouseScrollFixTests
