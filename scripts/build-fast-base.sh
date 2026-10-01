#!/bin/sh
# Validate the upstream fast base before integrating rescue payloads.
# All generated sources and artifacts live in this project's build directory.
set -eu
cd "$(dirname "$0")/.."
fast_min_kib=37748736
if [ "${ALPENGLOW_BOUNDED_FAST:-0}" = 1 ]; then fast_min_kib=33030144; fi
[ "$(df -Pk . | awk 'END {print $4}')" -ge "$fast_min_kib" ] || { echo 'Stop: need 30 GiB floor plus 6 GiB build allowance' >&2; exit 1; }
ZIG=${ZIG:-/opt/homebrew/Cellar/zig/0.16.0_1/bin/zig}
[ -x "$ZIG" ] || { echo 'Need a compatible Zig 0.16 compiler for the pinned fast init' >&2; exit 1; }
case "$("$ZIG" version)" in 0.16.*) ;; *) echo 'Need Zig 0.16' >&2; exit 1 ;; esac
for tool in docker lz4 cpio python3; do command -v "$tool" >/dev/null; done
python3 scripts/prepare-fast-base.py
export ZIG CARGO_BUILD_JOBS=2 MAKEFLAGS=-j2
# The copied recipe has pinned toolchain images, two-job limits and container
# headroom checks. BUILD_ONLY keeps upstream QEMU and auth services unlaunched.
ALPENGLOW_EDITION=potato BUILD_ONLY=1 INITRAMFS="$PWD/build/fast-source/build/native/initramfs.cpio.lz4" \
  sh build/fast-source/scripts/boot-native.sh
