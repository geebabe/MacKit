#!/bin/bash
set -euo pipefail

# Scripts/build_app.sh
# Builds MacKit executable and bundles it into dist/MacKit.app

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="${1:-debug}"
BUILD_DIR="${REPO_ROOT}/.build"
DIST_DIR="${REPO_ROOT}/dist"
APP_BUNDLE="${DIST_DIR}/MacKit.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building MacKit (${CONFIGURATION})..."
cd "${REPO_ROOT}"
if [ "${CONFIGURATION}" = "release" ]; then
    swift build -c release
    BIN_PATH="${BUILD_DIR}/release/MacKit"
else
    swift build
    BIN_PATH="${BUILD_DIR}/debug/MacKit"
fi

echo "==> Assembling app bundle at ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BIN_PATH}" "${MACOS_DIR}/MacKit"
cp "${REPO_ROOT}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Ad-hoc codesign to permit running locally on Apple Silicon
echo "==> Applying ad-hoc code signature..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "==> Verification:"
codesign --verify --deep --strict "${APP_BUNDLE}"
echo "==> Successfully created ${APP_BUNDLE}"
