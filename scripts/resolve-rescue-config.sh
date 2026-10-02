#!/bin/sh
# Resolve against the exact pinned kernel, without compiling rescue modules.
set -eu
cd "$(dirname "$0")/.."
luajit scripts/prepare-fast-base.lua
mkdir -p build/fast-source/build/native
DEBIAN=debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251
docker run --rm --cpus=1 --pids-limit=512 --label alpenglow-rescue.build=task15-fast-20261001 --platform linux/amd64 \
  -v "$PWD/build/fast-source/build/native:/out" -v "$PWD:/project:ro" -w /out "$DEBIAN" sh -c '
  set -eu
  [ "$(df -Pk /out | awk "END {print \$4}")" -ge 31457280 ]
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq build-essential bc bison flex libssl-dev libelf-dev libncurses-dev rsync kmod wget xz-utils ca-certificates luajit >/dev/null
  if [ ! -d linux-7.1.3 ]; then
    wget -q https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.3.tar.xz -O k.tar.xz
    printf "be41c068e88f5242a19bccdbffbe077b18c47b45f627e2325504b4fab79dd1dc  k.tar.xz\n" > kernel-download.sha256
    sha256sum -c kernel-download.sha256
    tar -xf k.tar.xz
  fi
  test "$(make -s -C linux-7.1.3 kernelversion)" = 7.1.3
  luajit /project/scripts/resolve-rescue-config.lua
  '
