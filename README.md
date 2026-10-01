# Alpenglow Rescue

A separate rescue-image project based on pinned Alpenglow, inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

Development goals: a complete compressed bootable artifact under 500,000,000
bytes and interactive rescue readiness in one-quarter the baseline time. These
are **targets, not achieved measurements**. Broad drivers, firmware and essential
rescue tools stay in the candidate, even if the image misses the size target.

The historical **partial core ISO is 1,014,913,024 bytes**. It reaches the Linux
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

The manual `Native fast-base image` Actions workflow builds the pinned base
and proof ISO with two jobs and verified toolchains. Local source checks are:

```sh
git submodule update --init
python3 scripts/prepare-fast-base.py --check
python3 scripts/test-recipes.py
```

The source submodule is unchanged. The measured historical core used Alpenglow's shared
rootfs assembly and Limine ISO layout, signed Alpine APK bootstrap with its
dependency solver, dinit, musl, toybox and oksh. The normal Oil bootstrap was
not used. The default recipe now targets the actual Alpenglow fast base;
that corrected base passed the GitHub/QEMU proof and is not integrated with rescue payloads.
Linux 7.1.3 is checksum-verified and the rescue fragment resolves all 141
requested settings; rescue drivers/modules have not been compiled or tested.
See [exact provenance and fast-path correction](docs/provenance-and-fast-path.md). The partial host packaging recipe is `scripts/pack-core-native.sh`;
it requires workspace-local xorriso and Limine tools described in the report.
Never interpret that partial artifact as a complete upstream equivalent.

Task-owned staging and packaging intermediates were removed after preserving
small manifests, logs and both measured ISOs. Details and exact paths are in
[evidence/cleanup-20261001.json](evidence/cleanup-20261001.json).

The [native rescue capability and disk plan](docs/rescue-capability-and-disk-plan.md)
records essential driver restoration, installed-size proxies and the original
40 GiB-reserve plan. A later exception permits only this 6 GiB fast-base run
with a monitored 30 GiB floor; the complete rescue build remains deferred.

The local cached compile was stopped when the user requested a GitHub-built
image as the primary test artifact. A later bounded continuation permits a
20 GiB floor on host and Docker, with a 4 GiB additional-allocation cap and
two build jobs; earlier disk and cleanup checkpoints remain preserved.

The upstream GitHub artifact `alpenglow-potato-x86_64` from run `35064440253`
was downloaded and its archive digest and ISO checksum verified. Its source
is `373c29c2cbb992e93175c4eea227c228a12a05dd`, distinct from our pinned base.
The **28,856,320-byte ISO** reached a BIOS serial login prompt in QEMU, but
login failed because the root shell field is `/bin/toybox sh`. It has no
rescue tools, AI clients or Oil, so its small size is not rescue equivalence.

The manual `Native fast-base image` workflow builds our pinned native recipe
with the `/bin/sh` correction, verified official toolchains and kernel archive,
and produces a proof ISO plus exact provenance. It uploads Actions artifacts;
it does not create a release. [Run 36865793057](https://github.com/undivisible/alpenglow-rescue/actions/runs/36865793057)
passed at source `ead71e23926b02a046769ada0787efd17bbf39e3`. Its downloaded
**9,795,584-byte proof ISO** passed three cold BIOS boots with interactive base
command response at **2.015 / 1.912 / 1.917 seconds** on ARM-host QEMU TCG.
Toybox 0.8.11 and dinit 0.19.2 CLI checks passed. A separate 60-second UEFI
trial reached no serial readiness marker; networking was disabled.
See [the GitHub image test report](docs/github-image-test.md) for exact hashes,
raw evidence and scope. This is a bare base, with rescue payload and essential
driver restoration still pending. No matched baseline or 4x comparison exists.
The supervisor stops owned jobs on errors or capacity limits.
