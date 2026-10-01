#!/bin/sh
# Resolve against the exact pinned kernel, without compiling rescue modules.
set -eu
cd "$(dirname "$0")/.."
python3 scripts/prepare-fast-base.py
mkdir -p build/fast-source/build/native
DEBIAN=debian:bookworm-slim@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251
docker run --rm --cpus=2 --pids-limit=512 --label alpenglow-rescue.build=task15-fast-20261001 --platform linux/amd64 \
  -v "$PWD/build/fast-source/build/native:/out" -v "$PWD:/project:ro" -w /out "$DEBIAN" sh -c '
  set -eu
  [ "$(df -Pk /out | awk "END {print \$4}")" -ge 31457280 ]
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq build-essential bc bison flex libssl-dev libelf-dev libncurses-dev rsync kmod wget xz-utils ca-certificates python3 >/dev/null
  if [ ! -d linux-7.1.3 ]; then
    wget -q https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.3.tar.xz -O k.tar.xz
    wget -q https://cdn.kernel.org/pub/linux/kernel/v7.x/sha256sums.asc -O kernel-sha256sums.asc
    python3 -c "import re; from pathlib import Path; t=Path(\"kernel-sha256sums.asc\").read_text(); m=re.search(r\"^([0-9a-f]{64})\\s+linux-7[.]1[.]3[.]tar[.]xz$\",t,re.M); assert m; Path(\"kernel-download.sha256\").write_text(m[1]+\"  k.tar.xz\\n\")"
    sha256sum -c kernel-download.sha256
    tar -xf k.tar.xz
  fi
  test "$(make -s -C linux-7.1.3 kernelversion)" = 7.1.3
  python3 /project/scripts/resolve-rescue-config.py
  '
