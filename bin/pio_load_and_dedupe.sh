#!/usr/bin/env bash
set -euo pipefail

PLATFORM_SRC="$1"
# Parse PlatformIO project output for all environments that include the specified platform source directory
to_build=$(
    platformio project config --json-output |
    jq -r ".[] | \
    select(.[0] | type==\"string\" and startswith(\"env:\")) | \
    select((.[1][] | select(.[0]==\"build_flags\") | .[1][] | test(\"-I\\\s?variants/$PLATFORM_SRC/\"))) | \
    .[0] | ltrimstr(\"env:\")"
)

echo "Gathering environments for platform: $PLATFORM_SRC"

echo "Installing global PlatformIO tools"
# Install additional tools
# `--no-save` prevents this from modifying platformio.ini
pio pkg install --global --no-save \
    --tool platformio/tool-cppcheck \
    --tool platformio/tool-mklittlefs \
    --tool platformio/tool-esptoolpy

echo "$to_build" | while read -r env; do
    echo "################################################"
    echo "▶️ Loading pkgs for env: $env"
    echo "################################################"
    # Install packages for building the PlatformIO environment
    pio pkg install --environment "$env"
done
echo "All packages loaded successfully."

# Replace duplicate files in the core directory with hard links
echo "Deduplicating $PLATFORMIO_CORE_DIR"
jdupes --quiet -r -L "$PLATFORMIO_CORE_DIR"

# Replace duplicate files in the workspace directory with hard links
echo "Deduplicating $PLATFORMIO_WORKSPACE_DIR"
jdupes --quiet -r -L "$PLATFORMIO_WORKSPACE_DIR"

echo "Deduplication complete."
