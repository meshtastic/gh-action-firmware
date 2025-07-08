# gh-action-firmware
Build Meshtastic firmware in an Action-container


## Usage

This action is meant to be used with [meshtastic/firmware](https://github.com/meshtastic/firmware) or forks.


### Example workflow

```yaml
jobs:
  build-nrf52:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v4
        with:
          repository: meshtastic/firmware
          ref: master

      - name: Get release version string
        shell: bash
        run: echo "long=$(./bin/buildinfo.py long)" >> $GITHUB_OUTPUT
        id: version

      - name: Build T-Echo
        id: build
        uses: meshtastic/gh-action-firmware@main
        with:
          pio_platform: nrf52
          pio_env: t-echo
          pio_target: build

      - name: Store binaries as an artifact
        uses: actions/upload-artifact@v4
        with:
          name: firmware-nrf52840-${{ inputs.board }}-${{ steps.version.outputs.long }}.zip
          overwrite: true
          path: |
            release/*.uf2
            release/*.elf
```

### Parameters

|Parameter|Description|Required|Default|
|---------|-----------|--------|-------|
|`pio_platform`|PlatformIO Platform|Yes||
|`pio_env`|PlatformIO "environment" (board)|Yes||
|`pio_target`|PlatformIO target operation|No|`build`|
|`ota_firmware_source`|OTA Binary to use (ESP32-only)|No||
|`ota_firmware_target`|OTA Binary destination (ESP32-Only)|No||
