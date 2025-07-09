#!/usr/bin/env bash
set -euo pipefail

# Define vars
GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

# Inputs
MT_TARGET=${MT_TARGET:-"build"}
MT_ENV=${MT_ENV}
MT_PLATFORM=${MT_PLATFORM}
MT_OTA_FIRMWARE_SOURCE=${MT_OTA_FIRMWARE_SOURCE:-""}
MT_OTA_FIRMWARE_TARGET=${MT_OTA_FIRMWARE_TARGET:-""}

# Build
if [ "$MT_TARGET" = "build" ]; then
    echo "Building PlatformIO environment: $MT_ENV"
    /workspace/bin/build-"${MT_PLATFORM}".sh "$MT_ENV"
    echo "Build artifacts are located at: $PLATFORMIO_BUILD_DIR"
    if [ -n "$MT_OTA_FIRMWARE_SOURCE" ] && [ -n "$MT_OTA_FIRMWARE_TARGET" ]; then
        echo "Downloading OTA firmware $MT_OTA_FIRMWARE_SOURCE from https://github.com/meshtastic/firmware-ota"
        curl -L "https://github.com/meshtastic/firmware-ota/releases/download/latest/$MT_OTA_FIRMWARE_SOURCE" -o "$MT_OTA_FIRMWARE_TARGET"
    fi
# Check
elif [ "$MT_TARGET" = "check" ]; then
    /workspace/bin/check-all.sh "$MT_ENV"
fi
