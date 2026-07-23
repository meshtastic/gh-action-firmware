#!/usr/bin/env bash
set -euo pipefail

# pioarduino uses uv with --force-reinstall unconditionally.
# https://github.com/pioarduino/platform-espressif32/blob/55.03.39/builder/penv_setup.py#L584-L588
# Patch the vendored espressif32 platform to drop `--force-reinstall` from the
# esptool install command. Runs at container-build time, AFTER `pio pkg install`
# has fetched the platform, so the patched copy is baked into /pio.
#
# Why: on every firmware build the platform re-verifies esptool and, when its
# `import esptool` guard misses, runs
#     uv pip install --quiet --force-reinstall -e <tool-esptoolpy>   (timeout=60)
# `--force-reinstall` implies uv's `--refresh`, so it re-fetches esptool and its
# dependencies from PyPI even though esptool is already baked into the image --
# and that network fetch occasionally exceeds the platform's 60s timeout.
# Without `--force-reinstall` the command is a fast no-op when esptool is already
# present, and still installs it (from the warm cache) if it genuinely isn't.

shopt -s nullglob globstar
files=(/pio/core/platforms/**/builder/penv_setup.py)

if [[ ${#files[@]} -eq 0 ]]; then
    echo "No pioarduino platform-espressif32 penv_setup.py found (non-esp32 platform?) - nothing to patch."
    exit 0
fi

for f in "${files[@]}"; do
    # Patch the uv pip install command to drop:
    # ` "--force-reinstall",`
    sed -i 's/ "--force-reinstall",//g' "$f"

    # Fail loudly if the expected command was not the one we patched (e.g. a
    # future platform release changed the argument order/wording).
    if grep -q -- "--force-reinstall" "$f"; then
        echo "ERROR: --force-reinstall still present in $f — upstream layout changed?" >&2
        exit 1
    fi

    # Drop any bytecode compiled from the pre-patch source so the patched .py wins.
    rm -f "$(dirname "$f")/__pycache__/penv_setup."*.pyc

    echo "Patched pioarduino (removed --force-reinstall): $f"
done
