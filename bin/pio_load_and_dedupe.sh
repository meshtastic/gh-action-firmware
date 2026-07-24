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

echo "$to_build" | while read -r env; do
    echo "################################################"
    echo "▶️ Loading pkgs for env: $env"
    echo "################################################"
    # Install packages for building the PlatformIO environment
    pio pkg install --environment "$env"
    # Install additional tools
    # `--no-save` prevents this from modifying platformio.ini
    pio pkg install --environment "$env" --no-save \
        --tool platformio/tool-cppcheck \
        --tool platformio/tool-mklittlefs
done
echo "All packages loaded successfully."


# PIOARDUINO HACK:
# https://github.com/pioarduino/platform-espressif32/blob/55.03.39/builder/penv_setup.py#L557-L578
# esp32: bake esptool as an *editable* install of the tool-esptoolpy package.
#
# The espressif32 platform expects `import esptool` to resolve from inside the
# tool-esptoolpy package dir. But esp-coredump (pulled in by the platform's
# Python-deps step) depends on esptool, so a *regular* copy lands in the penv's
# site-packages first and shadows it. The platform then fails its own check
#     dirname(esptool.__file__) startswith <.../packages/tool-esptoolpy>
# on every build and re-runs `uv pip install --force-reinstall -e ...`, which
# re-fetches from PyPI and occasionally exceeds its 60s timeout.
#
# Fixing it here (in the penv, which is core-level state that survives `pio run`
# — unlike the platform dir, which is re-extracted and would revert edits) makes
# that check pass, so the platform skips the reinstall entirely at build time.
if [[ "$PLATFORM_SRC" == esp32* ]]; then
    penv="$PLATFORMIO_CORE_DIR/penv"
    esptool_pkg="$PLATFORMIO_CORE_DIR/packages/tool-esptoolpy"
    if [[ -x "$penv/bin/uv" && -d "$esptool_pkg" ]]; then
        echo "Baking editable esptool from $esptool_pkg"
        export UV_CACHE_DIR="$PLATFORMIO_CORE_DIR/.cache/uv"
        # Drop the regular (esp-coredump-pulled) esptool, then install the tool
        # package editable so it resolves from inside tool-esptoolpy.
        "$penv/bin/uv" pip uninstall --python "$penv/bin/python" esptool 2>/dev/null || true
        "$penv/bin/uv" pip install --python "$penv/bin/python" -e "$esptool_pkg"
        # Precompile so the platform's 5s `import esptool` check is never the bottleneck.
        "$penv/bin/python" -m compileall -q "$penv" "$esptool_pkg" || true
        # Assert the platform's MATCH condition now holds; fail the build loudly if not.
        "$penv/bin/python" - "$esptool_pkg" <<'PY'
import esptool, os, sys
expected = os.path.normcase(os.path.realpath(sys.argv[1]))
actual = os.path.normcase(os.path.realpath(os.path.dirname(esptool.__file__)))
if not actual.startswith(expected):
    sys.exit(f"ERROR: esptool did not install editable under {expected} (got {actual})")
print(f"esptool editable OK: {actual}")
PY
    else
        echo "WARNING: penv uv or tool-esptoolpy not found; skipping esptool bake." >&2
    fi
fi

if [[ "$PLATFORM_SRC" != esp32* ]]; then
    # Replace duplicate files in the core directory with hard links
    echo "Deduplicating $PLATFORMIO_CORE_DIR"
    jdupes --quiet -r -L "$PLATFORMIO_CORE_DIR"
fi

# Replace duplicate files in the workspace directory with hard links
echo "Deduplicating $PLATFORMIO_WORKSPACE_DIR"
jdupes --quiet -r -L "$PLATFORMIO_WORKSPACE_DIR"

echo "Deduplication complete."
