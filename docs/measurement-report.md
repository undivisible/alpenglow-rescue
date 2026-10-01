# Development measurement report, 2026-10-01

The full goal is **not achieved**. A partial core ISO was built and reached
the Linux kernel, but no valid interactive-ready time or speed ratio exists.
The ISO already exceeds 500,000,000 bytes before adding AI clients and Oil.
No binaries, GitHub release, or announcement were published.

## Sources and isolation

- Alpenglow: `tschk/alpenglow`, verified remotely at
  `2214bc159355522bbebc61e8e90ca78933a8e1ac` (MPL-2.0).
- Omarchy Rescue current documentation: `ae903cd63a43aa609a7b5493b45647aa53a7cf73`.
- Official baseline: `v2026.09.30.1`, tag commit
  `2c52ef26fb2a5b6d2f9605dd61bef96c237e6494`.
- Project has its own Git history and a pinned public Alpenglow submodule.
  Original Alpenglow paths were unchanged, including their `.grok-burns/` WIP.
- Build concurrency: two jobs/CPUs. No privileged containers, host OS changes,
  real disk mounts/writes, USB flashing, credentials, authentication enrollment,
  host-forwarded remote root shells, or broad cleanup.

## Exact artifact measurements

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Partial core ISO | 1,014,913,024 | `6fe574f213acaccbc8eb99ef2387e1dbeedbb512bcd0a1b3a04cfac14fb2f528` |
| Core zstd initramfs | 996,492,127 | `696e8a882de8dbe7bfe1dc4c3fa11d81e3257338bd38e26d0ee67a1089250504` |
| Alpine LTS kernel | 14,541,824 | `73833ffe45bed7bde514dea76a28c3116f98a3f748ee5bab5d60b7cc05598fb9` |
| Official baseline ISO | 1,954,578,432 | `b812a848e93bc5526094a8165fba8564e9211a7e86859faba2fd525b6bcd82f1` |

Baseline passed its separately downloaded official `.sha256` check. Upstream
README's ~1.8 GB rescue-only and ~6.6 GB installer figures are estimates, not
the exact measurements above. Core and baseline sizes are not a parity claim.

The core contains 347 APK packages. Firmware occupies 751,036 KiB and kernel
modules about 133,524 KiB in the staged tree, without driver/firmware trimming.
Exact package versions, source names and license metadata are in
`evidence/package-license-inventory.json`. Key versions: Linux 6.18.54,
dinit 0.19.4, musl, toybox source 0.8.11, oksh 7.8, tmux 3.6,
cryptsetup 2.8.1, btrfs-progs 6.17.1, iwd 3.10.

## Boot attempts and limits

Host: cp.local, ARM64 macOS. QEMU 11.0.2 x86_64 TCG, q35, CPU max,
2 vCPUs, 4096 MiB RAM, read-only IDE CD-ROM, e1000/private user network,
no target disk. BIOS used the same default SeaBIOS file. Firmware checksums
are retained in `evidence/qemu-firmware.sha256`. UEFI files were located and
hashed but **UEFI was not boot-tested**.

| Run | Observation | Rescue ready | Network ready |
| --- | --- | --- | --- |
| Baseline BIOS diagnostic, 90 s | systemd boot in progress; background build active | not established | not established |
| Baseline BIOS cold attempt 1, 240 s | reached visible upstream rescue tmux console; probe input did not produce marker | not established | not established |
| Baseline attempt 2 | interrupted to correct keyboard instrumentation; raw log preserved | not established | not established |
| Core BIOS diagnostic, 120 s | Limine loaded Linux; initramfs unpack started, init/dinit not observed | not established | not established |

The earlier probe used PS/2 input; the next recipe adds USB keyboard input to
both guests. The core diagnostic already used that revised device setup.
No matched set of three valid runs exists. Some diagnostics overlapped small
packaging work and are excluded from comparative claims. A login prompt or
visible tmux welcome is not the defined end marker. ARM emulation behavior,
large RAM-root unpacking, input instrumentation, and resource pressure remain
unresolved. Do not infer hardware boot time, a median, or a 4x speedup.

Raw serial logs, commands, screenshots and result JSON remain under
`build/bench/`; the official baseline ISO remains in the task's `baseline/`.

## Validation

- Recipe syntax/safety checks passed (`python3 scripts/test-recipes.py`).
- Signed APK install completed: 347 packages, 1222.1 MiB reported by APK.
- A read-only, network-disabled container launched core tool versions/help:
  cryptsetup, Btrfs, ddrescue, TestDisk, SMART, NVMe, mdadm, chroot, tmux,
  dinit and oksh. LVM help exited 4 because the staged root has no mounted
  `/proc`; the smoke result explicitly reports partial, not pass.
- No synthetic filesystem fixtures or real repair were tested.
- Pinned Alpenglow `ci-os-appliance.sh` was attempted and failed at its
  pre-existing macOS edition export check (missing potato arm64 tar);
  profile matrix passed. Rust core gate and AI smoke checks were not run.
- Alpenglow submodule and original checkout remain unchanged.

## Resource stop and remaining work

Full container build stopped at 19,780,896 KiB free, below its 20 GiB reserve,
before AI downloads and Oil compilation. After container exit its filesystem
still reported 20,117,540 KiB. Host had enough room for bounded native core
packaging; subsequent VM/memory pressure briefly reduced host free space below
20 GiB. Large builds and VM runs were stopped. The current policy is a
**40 GiB reserve**; the earlier 20 GiB guards have been corrected. New large
builds stay paused pending the real fast-path disk budget.

Native packaging tools stayed in `build/native-tools/`: GNU xorriso
1.5.6.pl02 source, compiled with `gmake MAKE=gmake -j2` and a workspace prefix,
plus Limine 12.4.0 binary release. Their exact archive hashes are retained.
The partial packaging reused the Alpenglow Limine/xorriso release layout,
with BSD cpio on macOS and no disk-image mount or installer. Only duplicate
task-owned boot payloads generated by APK were removed from staging.

Next work requires adequate headroom: change the large RAM-root path to the
existing immutable erofs/squashfs packaging design, validate interactive
console/network readiness, build and smoke all three AI clients and Oil,
finish mount/phone/kmscon integration and other listed gaps, run synthetic
read-only fixture tests, then collect three matched BIOS and UEFI trials.
Any architecture-only firmware exclusions need an explicit coverage audit;
do not remove essential rescue tools or supported drivers to win the size goal.

## Source repository and cleanup checkpoint

The private repository was successfully created and source pushed after the
later user request superseded the original no-push restriction:
https://github.com/undivisible/alpenglow-rescue (default branch `main`).
Initial pushed source commit: `48d7e10c069e0d23a38fb6ef78ca025f53aa99e4`.
No binary release or social post was created. The first creation attempt was
rejected by review; one authorized same-route retry then succeeded.

The user subsequently authorized task-owned rebuildable intermediate cleanup.
No build/VM/container was active. Removed paths, size inventory and observed
free-space bytes are in `evidence/cleanup-20261001.json`. The sole measured
core ISO and official baseline were preserved, along with source/WIP/Git,
small logs/manifests/checksums and raw benchmark evidence. The core ISO hash
was checked before and after cleanup and still matches the table above.
Deleted intermediate initramfs and kernel payloads remain inside that ISO.

The eight removed paths represented **2,384,809,984 allocated bytes**, counting
hardlinks once. Observed volume availability immediately before/after the
removal was **34,613,784,576 / 34,848,399,360 bytes**. Shared APFS and another
cleanup task affect physical space, so the observed delta is not an isolated
measurement of this cleanup's physical reclamation. No unfamiliar data,
Docker global cache, Trash, or other task outputs were touched.

The measured prototype was not Alpenglow's fast image. Exact source/recipe
provenance, component sizes and the corrected default fast-base route are in
`docs/provenance-and-fast-path.md`. Only syntax/adaptation checks were run for
the corrected route; no large rebuild or new boot benchmark was started.
The manifest `recipe-file-sha256-built-core.json` preserves recipe hashes from
the measured build; `recipe-file-sha256.json` describes the current sources.

A later local-only checkpoint independently audits the native FAST boot path,
proposes essential rescue driver restoration and sets conservative 6 GiB
fast-base / 16 GiB complete-rescue temporary budgets above the 40 GiB reserve.
See `docs/rescue-capability-and-disk-plan.md`. No large build, new image, boot
trial or further push attempt accompanied that checkpoint.
