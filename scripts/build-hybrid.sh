#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
free_kb=$(df -Pk . | awk 'END {print $4}')
[ "$free_kb" -ge 41943040 ] || { echo 'Stop: less than 40 GiB host headroom' >&2; exit 1; }
[ "$(git -C vendor/alpenglow rev-parse HEAD)" = 2214bc159355522bbebc61e8e90ca78933a8e1ac ]
mkdir -p build
docker run --rm --cpus=1 --pids-limit=512 --platform linux/amd64 \
  -e CARGO_BUILD_JOBS=1 -e MAKEFLAGS=-j1 \
  -v "$PWD:/project" -w /project \
  alpine:3.23@sha256:85fe1e81d6758c208f3e1eed4338a1997e19d4be002d4dd32d3100c9a8c010a0 \
  sh scripts/build-container.sh
