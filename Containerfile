# syntax=docker/dockerfile:1

# Base image
FROM python:3.14-trixie AS base
ENV PIP_ROOT_USER_ACTION=ignore
ENV DEBIAN_FRONTEND=noninteractive

# Deb-multimedia repository (provides libpcre3)
RUN echo 'deb https://www.deb-multimedia.org trixie main' > /etc/apt/sources.list.d/deb-multimedia.list \
    && apt-get -o Acquire::AllowInsecureRepositories=true update \
    && apt-get install -y --no-install-recommends --allow-unauthenticated deb-multimedia-keyring \
    && rm -rf /var/lib/apt/lists/*

# Apt dependencies
RUN apt-get update && apt-get install -y \
    jq jdupes build-essential \
    libgpiod-dev libyaml-cpp-dev libbluetooth-dev libusb-1.0-0-dev libi2c-dev libuv1-dev \
    libx11-dev libinput-dev libxkbcommon-x11-dev \
    openssl libssl-dev libulfius-dev liborcania-dev \
    libpcre3-dev \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
# ESP32 targets build against pioarduino, everything else against upstream platformio.
ARG PIO_PLATFORM
COPY requirements_*.txt /tmp/
RUN case "${PIO_PLATFORM}" in \
    esp32*) pip install -r /tmp/requirements_pioarduino.txt ;; \
    *) pip install -r /tmp/requirements_platformio.txt ;; \
    esac

# PlatformIO Configuration
ENV PLATFORMIO_CORE_DIR=/pio/core
ENV PLATFORMIO_WORKSPACE_DIR=/pio/workspace
ENV PLATFORMIO_SETTING_ENABLE_TELEMETRY=0
ENV CI=true

# Set UV_LINK_MODE to copy (it creates hardlinks by default)
ENV UV_LINK_MODE=copy

# Gather PlatformIO dependencies in a separate stage
FROM base AS pio_deps
ARG DEPS_FROM_REPO="https://github.com/meshtastic/firmware.git"
ARG DEPS_FROM_REF
ARG PIO_PLATFORM

RUN git clone --depth 1 --recurse-submodules --shallow-submodules \
    --branch "${DEPS_FROM_REF}" "${DEPS_FROM_REPO}" /deps
WORKDIR /deps

COPY ./bin/pio_load_and_dedupe.sh /pio_load_and_dedupe.sh
RUN /pio_load_and_dedupe.sh ${PIO_PLATFORM}

# Builder image
FROM base
LABEL org.opencontainers.image.authors="vidplace7"

# /pio is heavily hardlinked by jdupes (see bin/pio_load_and_dedupe.sh) to shrink
# it. A plain `COPY --from` flattens every hardlink back into a full copy, undoing
# the dedup in the final image. Stream through tar over a bind mount instead: tar
# preserves hardlinks (and symlinks), and the bind mount means no intermediate
# tarball is ever written to a layer.
RUN --mount=type=bind,from=pio_deps,source=/pio/workspace,target=/mnt/pio-workspace \
    mkdir -p /pio/workspace && tar -C /mnt/pio-workspace -cf - . | tar -C /pio/workspace -xf -
RUN --mount=type=bind,from=pio_deps,source=/pio/core,target=/mnt/pio-core \
    mkdir -p /pio/core && tar -C /mnt/pio-core -cf - . | tar -C /pio/core -xf -

WORKDIR /workspace
RUN git config --global --add safe.directory /workspace

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
