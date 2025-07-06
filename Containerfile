# Base image
FROM python:3.13-bookworm AS base
ENV PIP_ROOT_USER_ACTION=ignore

# Apt dependencies
RUN apt-get update && apt-get install -y \
    jq jdupes build-essential \
    libgpiod-dev libyaml-cpp-dev libbluetooth-dev libusb-1.0-0-dev libi2c-dev libuv1-dev \
    libx11-dev libinput-dev libxkbcommon-x11-dev \
    openssl libssl-dev libulfius-dev liborcania-dev \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# PlatformIO Configuration
ENV PLATFORMIO_CORE_DIR=/pio/core
ENV PLATFORMIO_WORKSPACE_DIR=/pio/workspace

# Gather PlatformIO dependencies in a separate stage
FROM base AS pio_deps
ARG DEPS_FROM_REPO="https://github.com/meshtastic/firmware.git"
ARG DEPS_FROM_REF="master"
ARG PIO_PLATFORM

RUN git clone --depth 1 --recurse-submodules --shallow-submodules \
    --branch "${DEPS_FROM_REF}" "${DEPS_FROM_REPO}" /deps
WORKDIR /deps

COPY ./bin/pio_load_and_dedupe.sh /pio_load_and_dedupe.sh
RUN /pio_load_and_dedupe.sh ${PIO_PLATFORM}
# RUN platformio pkg install -e native-tft

# Builder image
FROM base
LABEL org.opencontainers.image.authors="vidplace7"

COPY --from=pio_deps /pio /pio

WORKDIR /workspace
RUN git config --global --add safe.directory /workspace

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
