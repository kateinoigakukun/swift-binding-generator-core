#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.txt for the list of Swift.org project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# Builds and tests swift-java against THIS checkout of swift-binding-generator-core,
# so we notice source breaks in our primary consumer early.
#
# Usage:
#   SWIFT_JAVA_REPOSITORY=swiftlang/swift-java SWIFT_JAVA_REF=main ./.github/scripts/test_swift_java.sh
#
# SWIFT_JAVA_REPOSITORY accepts an owner/repo shorthand, a full git URL, or a
# file:// URL (handy for testing against a local checkout).
# SWIFT_JAVA_REF is any branch, tag, or SHA (default: main).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
declare -r REPO_ROOT
declare -r DOWNSTREAM_DIR="$REPO_ROOT/.downstream/swift-java"

SWIFT_JAVA_REPOSITORY="${SWIFT_JAVA_REPOSITORY:-swiftlang/swift-java}"
SWIFT_JAVA_REF="${SWIFT_JAVA_REF:-main}"

# Normalize owner/repo shorthand into a full URL
if [[ "$SWIFT_JAVA_REPOSITORY" != *"://"* && "$SWIFT_JAVA_REPOSITORY" != /* && "$SWIFT_JAVA_REPOSITORY" != git@* ]]; then
  SWIFT_JAVA_REPOSITORY="https://github.com/$SWIFT_JAVA_REPOSITORY"
fi

echo "=== swift-java compatibility check ==="
echo "swift-java repository: $SWIFT_JAVA_REPOSITORY"
echo "swift-java ref:        $SWIFT_JAVA_REF"
echo "core checkout:         $REPO_ROOT"

if [[ -d "$DOWNSTREAM_DIR/.git" ]]; then
  echo "--- Reusing existing clone in $DOWNSTREAM_DIR"
  git -C "$DOWNSTREAM_DIR" fetch --depth 1 origin "$SWIFT_JAVA_REF"
  git -C "$DOWNSTREAM_DIR" checkout FETCH_HEAD
else
  echo "--- Cloning swift-java into $DOWNSTREAM_DIR"
  mkdir -p "$(dirname "$DOWNSTREAM_DIR")"
  git clone --depth 1 --branch "$SWIFT_JAVA_REF" "$SWIFT_JAVA_REPOSITORY" "$DOWNSTREAM_DIR"
fi

# Point swift-java at THIS checkout of swift-binding-generator-core
export SWIFT_BINDING_GENERATOR_CORE_PATH="$REPO_ROOT"

cd "$DOWNSTREAM_DIR"

echo "--- Verifying the local override took effect"
declare deps
deps="$(swift package show-dependencies)"
echo "$deps"
if ! grep -q "swift-binding-generator-core" <<<"$deps"; then
  echo "::error::swift-java does not depend on swift-binding-generator-core at all."
  echo "This usually means the swift-java ref ($SWIFT_JAVA_REF) predates the SwiftExtract split."
  echo "Pass a newer ref via SWIFT_JAVA_REF, or ignore this failure until the split lands in swift-java."
  exit 1
fi
# A path-based dependency shows up without a resolved remote version; make sure
# we did not silently resolve the package from GitHub instead of this checkout.
if swift package show-dependencies --format json | grep -q '"url"[[:space:]]*:[[:space:]]*"https://github.com/swiftlang/swift-binding-generator-core'; then
  echo "::error::swift-binding-generator-core was resolved from GitHub, not from $REPO_ROOT."
  echo "The SWIFT_BINDING_GENERATOR_CORE_PATH override did not take effect."
  exit 1
fi

echo "--- Building swift-java (with tests)"
swift build --build-tests --disable-experimental-prebuilts

echo "--- Testing swift-java"
swift test --disable-experimental-prebuilts

echo "--- Checking vendored SwiftExtractConfigurationShared copies are in sync"
# swift-java's SwiftPM plugins cannot take sources from a dependency, so it
# vendors byte-identical copies of SwiftExtractConfigurationShared under
# Plugins/PluginsShared. Diff them so drift between the two repos shows up here.
diff -r -x DO_NOT_EDIT.txt \
  "$REPO_ROOT/Sources/SwiftExtractConfigurationShared" \
  "$DOWNSTREAM_DIR/Plugins/PluginsShared/SwiftExtractConfigurationShared"

echo "=== swift-java compatibility check PASSED ==="
