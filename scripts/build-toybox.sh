#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ "$(df -Pk . | awk 'END {print $4}')" -ge 20971520 ]
mkdir -p build/native build/downloads build/evidence
docker run --rm --cpus=2 --pids-limit=128 --platform linux/amd64 \
  -v "$PWD:/project" -w /project \
  alpine:3.21@sha256:ce64758a109eb420d874a118f87920e625e12d3634e03b4a5573fd9f6e5d3507 sh -c '
    apk add --no-cache build-base bash curl linux-headers >/dev/null
    if [ ! -d build/toybox-0.8.11 ]; then
      curl -fL https://github.com/landley/toybox/archive/refs/tags/0.8.11.tar.gz -o build/downloads/toybox-0.8.11.tar.gz
      tar -xzf build/downloads/toybox-0.8.11.tar.gz -C build
    fi
    sha256sum build/downloads/toybox-0.8.11.tar.gz > build/evidence/toybox-source.sha256
    cd build/toybox-0.8.11
    make defconfig
    sed -i "s/# CONFIG_STATIC is not set/CONFIG_STATIC=y/;s/# CONFIG_SH is not set/CONFIG_SH=y/;s/# CONFIG_GETTY is not set/CONFIG_GETTY=y/" .config
    # The strncat macro precedes fortify headers; include declarations first.
    CPUS=2 make -j2 CFLAGS="-D_GNU_SOURCE -include string.h" LDFLAGS=-static > /project/build/toybox-build.log 2>&1
    cp toybox ../native/toybox
  '
