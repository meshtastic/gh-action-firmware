#!/usr/bin/env bash
set -euo pipefail

# Define vars
GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}
XDG_CACHE_HOME=${XDG_CACHE_HOME:-$HOME/.cache}

# Inputs
MT_TARGET=${MT_TARGET:-"build"}
MT_ENV=${MT_ENV}
MT_PLATFORM=${MT_PLATFORM}

# Massage platform values to build_script names
if [[ "$MT_PLATFORM" == esp32* ]]; then
    MT_PLATFORM="esp32"
elif [[ "$MT_PLATFORM" == nrf52* ]]; then
    MT_PLATFORM="nrf52"
elif [[ "$MT_PLATFORM" == rp2040 ]] || [[ "$MT_PLATFORM" == rp2350 ]]; then
    MT_PLATFORM="rp2xx0"
elif [[ "$MT_PLATFORM" == stm32 ]]; then
    # Remove when stm32 has been fully renamed to stm32wl
    MT_PLATFORM="stm32wl"
fi

# Build
if [ "$MT_TARGET" = "build" ]; then
    echo "Building PlatformIO environment: $MT_ENV"
    /workspace/bin/build-"${MT_PLATFORM}".sh "$MT_ENV"
    echo "Build artifacts are located at: $PLATFORMIO_BUILD_DIR"
# Check
elif [ "$MT_TARGET" = "check" ]; then
    /workspace/bin/check-all.sh "$MT_ENV"
fi
