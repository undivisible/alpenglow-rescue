# Alpenglow Rescue

A separate rescue-image project based on pinned Alpenglow, inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

Development goals: a complete compressed bootable artifact under 500,000,000
bytes and interactive rescue readiness in one-quarter the baseline time. These
are **targets, not achieved measurements**. Broad drivers, firmware and essential
rescue tools stay in the candidate, even if the image misses the size target.

The current **partial core ISO is 1,014,913,024 bytes**. It reaches the Linux
kernel in BIOS QEMU, but interactive rescue readiness was not established.
AI clients and Oil are absent after a disk-headroom stop. Neither goal has
been met. See the [measurement report](docs/measurement-report.md),
[feature and license matrix](docs/feature-license-matrix.md), and
[benchmark protocol](docs/benchmark-method.md).
No authentication, host-disk repair, USB flashing, binary release, or social
announcement is part of this development run.

The Alpenglow submodule is pinned to `2214bc159355522bbebc61e8e90ca78933a8e1ac`.
Alpenglow-derived sources and this project use MPL-2.0. Image components retain
their own licenses; Omarchy Rescue's MIT attribution is in `licenses/`.

Validate the actual pinned fast base after its disk budget is established
and at least 40 GiB host/container reserve remains:

```sh
git submodule update --init
python3 scripts/prepare-fast-base.py --check
sh scripts/build.sh
python3 scripts/test-recipes.py
```

The source submodule is unchanged. The measured historical core used Alpenglow's shared
rootfs assembly and Limine ISO layout, signed Alpine APK bootstrap with its
dependency solver, dinit, musl, toybox and oksh. The normal Oil bootstrap was
not used. The default recipe now targets the actual Alpenglow fast base;
that corrected base has not been built or integrated with rescue payloads.
See [exact provenance and fast-path correction](docs/provenance-and-fast-path.md). The partial host packaging recipe is `scripts/pack-core-native.sh`;
it requires workspace-local xorriso and Limine tools described in the report.
Never interpret that partial artifact as a complete upstream equivalent.

Task-owned staging and packaging intermediates were removed after preserving
small manifests, logs and both measured ISOs. Details and exact paths are in
[evidence/cleanup-20261001.json](evidence/cleanup-20261001.json).

The [native rescue capability and disk plan](docs/rescue-capability-and-disk-plan.md)
records essential driver restoration, installed-size proxies and the 46 GiB
fast-base / 56 GiB complete-build entry thresholds. Current space is insufficient.
