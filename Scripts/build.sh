#!/bin/sh
# Builds Atrium from the command line. Usage: Scripts/build.sh [Debug|Release]
set -eu
cd "$(dirname "$0")/.."
CONFIG="${1:-Debug}"
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen" >&2; exit 1; }
./Scripts/generate-secrets.sh .env Atrium/Support/Secrets.generated.swift
xcodegen generate --quiet
xcodebuild -project Atrium.xcodeproj -scheme Atrium -configuration "$CONFIG" \
    -derivedDataPath "${DERIVED_DATA:-build/DerivedData}" build | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true
