# Why the measured core is 1 GB

The measured ISO did **not** use Alpenglow's fast kernel or its fast rootfs.
It was a hybrid prototype: Alpine 3.23 signed APK dependency installation,
Alpine's Linux LTS 6.18.54 kernel, 347 packages, all linux-firmware packages,
and a 996,492,127-byte zstd initramfs. It reused Alpenglow's shared minimal
rootfs configuration, toybox source/version, dinit design and Limine release
layout. It used a shell `/init`, not upstream's compiled Zig `/init`.
Oil was not built or run. No Alpenglow release image was used.

That packaging choice produced the 1,014,913,024-byte ISO. The feature matrix
and CLI smoke results describe this partial prototype, not fast-image parity.
It never reached the defined interactive rescue readiness marker.

| Staged component | Allocated KiB | Role |
| --- | ---: | --- |
| Firmware | 751,036 | All Alpine firmware dependencies, not architecture-filtered |
| Kernel modules | 132,924 | Alpine LTS broad driver modules |
| `/usr/bin` | 187,528 | Rescue and supporting programs, including rclone/restic |
| `/usr/lib` | 102,548 | Shared libraries and language dependencies |
| `/usr/share` | 58,020 | Data and documentation |

Largest APK installed sizes: Qualcomm firmware 182,230,772 B, linux-lts
150,677,193 B (before duplicate boot payload removal), NVIDIA firmware
108,571,319 B, Intel firmware 106,729,002 B, rclone 105,040,120 B, Mellanox
firmware 93,752,967 B, Marvell firmware 81,010,777 B, restic 48,080,392 B,
Perl 40,225,349 B. These are installed package bytes, not each component's
contribution to compressed ISO bytes. Full inventory is in
`evidence/core-size-breakdown.json` and `evidence/package-license-inventory.json`.

## The actual pinned fast path

At Alpenglow `2214bc159355522bbebc61e8e90ca78933a8e1ac`:

- `scripts/boot-native.sh`, `ALPENGLOW_EDITION=potato`, resolves `FAST=1`,
  minimal userspace, headless, diskless, SeaBIOS, compiled Zig `/init`.
- toybox 0.8.11 and static dinit 0.19.2 are built from source. The fast rootfs
  is composed from those programs and serial login units, not an APK distro
  root. Fast/minimal composition skips Oil and uses toybox shell.
- LZ4 initramfs is embedded by `build-kernel-fast.sh` in custom Linux 7.1.3.
  The recipe starts with `alpenglow-qemu-minimal.config`, `lz4.config`,
  `virt.config`, then `fast.config` and explicit fast-only disables.
- The dated upstream docs report a 7,222,272-byte kernel and 2,313,448-byte
  initramfs for a slim fast run. They report no full ISO for that run and
  login timing on a different x86 host. These are upstream records, not
  measurements of this rescue project or cp.local.

The fast-only kernel disables USB/HID, SCSI/ATA/SATA, NVMe, Wi-Fi, IPv6,
Btrfs/XFS/FAT/NTFS and ISO9660, among other features. Using that unchanged as
an Omarchy rescue equivalent would hide essential capability gaps.

## Corrected development route

The default `scripts/build.sh` now routes to `build-fast-base.sh`, which
prepares the real pinned fast recipe in `build/fast-source/`. It leaves the
submodule and original WIP untouched. Adaptations only limit jobs/CPUs to two,
pin official container toolchains, add disk guards, cap zstd threads and apply
the known toybox fortify-header-order correction. `BUILD_ONLY=1` launches no VM.
`prepare-fast-base.py --check` verifies the edits in memory; it does not build.
The old recipe is explicitly retained as `build-hybrid.sh` for provenance.

**The corrected fast base has not been built or booted here.** It is a base
validation step, not a rescue ISO. Before building, account for kernel source,
objects, container layers and export size; the 2 GiB entry allowance is a
minimum gate, not a measured kernel-build budget. Keep 40 GiB host/container
reserve throughout and preserve Twenify's priority.

The rescue integration needs matching custom-kernel storage/USB/Wi-Fi and
filesystem support, modules/firmware coverage audited for x86_64, and a lean
early init plus an explicitly selected read-only rescue payload. The existing
erofs/squashfs appliance design is useful, but its automatic disk scanning
and mandatory writable bcachefs state mount cannot be copied into this rescue
workflow. Rescue payloads must be mounted only from the explicitly provided
boot medium; target disks stay untouched. Add the essential tools and all
three AI clients, then verify CLI/fixtures and matched readiness benchmarks.
Architecture-only firmware exclusions may save bytes, after a coverage audit;
no essential capability was removed during the disk cleanup.

Oil's source `run_system_add` selects named packages and `install_package`
downloads/extracts them; that path does not call the dependency resolver used
by regular install. Its default Alpenglow branch detection targets Alpine
v3.20, while this prototype bootstrapped v3.23. These are source-inspection
concerns, not an observed Oil runtime failure. APK bootstrap cannot be
silently described as a verified native Oil pipeline.
