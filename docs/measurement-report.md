# Current measurements, 2026-10-01

The [2026-10-02 LuaJIT tooling migration](luajit-migration.md) is validated
locally but has not produced a new image or boot measurement. All artifact
hashes and times below describe the earlier commits explicitly identified here.

The native storage increment produces a bootable **33,658,880-byte partial
candidate**, with interactive command response under BIOS and UEFI. Storage
rescue readiness is unproven: the latest strict probe exits 125 before the
filesystem/tmux/LUKS tests. Networking, firmware coverage, Oil, AI clients and
workflow helpers remain incomplete. No complete under-500-MB or 4x claim,
final binary release or social post is supported.

## Sources and whole-image measurements

Alpenglow: `2214bc159355522bbebc61e8e90ca78933a8e1ac` (MPL-2.0).
Original checkouts and `.grok-burns/` WIP remain untouched. Comparison README:
Omarchy Rescue `ae903cd63a43aa609a7b5493b45647aa53a7cf73` (MIT).
Official baseline `v2026.09.30.1`:
`2c52ef26fb2a5b6d2f9605dd61bef96c237e6494`.

| Artifact | Complete ISO bytes | SHA-256 |
| --- | ---: | --- |
| Latest corrected native storage-1a | 33,658,880 | `2dd28a8cc383ef347879887b4e97c99a1f7e434a63ef52333b246eca498c87af` |
| Original compiled native storage-1 | 33,638,400 | `2116c874884540f9977ea73103f6fa1e5aa57d3689c4bc8a4b43baf67a33ef65` |
| Earlier bare native proof | 9,795,584 | `f3ed7b265446c4d0a4af92352af61bed8ed0471da3fd7fa9d7300af7f806ba1a` |
| Historical Alpine-kernel prototype | 1,014,913,024 | `6fe574f213acaccbc8eb99ef2387e1dbeedbb512bcd0a1b3a04cfac14fb2f528` |
| Checksum-verified official baseline | 1,954,578,432 | `b812a848e93bc5526094a8165fba8564e9211a7e86859faba2fd525b6bcd82f1` |

These include the complete compressed root payload and bootloader; the outer
Actions ZIP is not the image-size measurement. Official baseline checksum:
`evidence/baseline-official.sha256`. Upstream README estimates ~1.8 GB
rescue-only/~6.6 GB installer are separate from measured release bytes.

## Native lineage and licenses

The native storage kernel was built at project source
`e4ef9d31516ed23a4610678d828dd7178b0e5a42` in
[run 36877105791](https://github.com/undivisible/alpenglow-rescue/actions/runs/36877105791).
All 106 requested storage/EFI settings resolved to `y` and compiled.
Linux 7.1.3 `vmlinuz`: 29,647,872 bytes, SHA-256
`d0de6039b139c1c5eed984ae74a836c1d1c6136c9dc741f0a7642f131882ec34`.
Embedded LZ4 root: 19,697,499 bytes, SHA-256
`996dcd5eac4f914b08853a4517e5a34905be23e09733460fde331f2ad2f0bb84`.
Zig init, static Toybox 0.8.11 and dinit 0.19.2 were hash-checked before/after
adding signed APK storage tools; the native core stayed identical.

Latest ISO: project `4602cc54681f858e1388661f7aebda4754306ae1`,
[run 36883059485](https://github.com/undivisible/alpenglow-rescue/actions/runs/36883059485).
It preserves the exact native kernel and adds an **18,454-byte** gzip
supplemental initramfs for `/bin/sh -> /usr/bin/oksh`, Toybox executable links,
signed ncurses terminfo and the strict helper. Supplemental SHA-256:
`571861e747243695036796a77dec0e973444a0c40ac583848bdb7d5338b77dca`.
The source recipe now includes those corrections before root compression;
that revised full recipe has not completed a successful image test.

[Temporary image artifact](https://github.com/undivisible/alpenglow-rescue/actions/runs/36883059485/artifacts/11172152320):
ZIP 28,087,234 bytes, SHA-256
`a90e02ea429ce360088c6c744fc70c3a608f1be0109f38af11e30bbc58d33668`.
The whole ISO was independently hashed within CI; no new ISO was downloaded
locally after the disk stop. Small raw evidence ZIP was downloaded, checked
against GitHub's archive digest and extracted only as JSON/serial text.

Exact config/core hashes, 86 resolved APK records, versions, licenses,
origins/source recipe commits and staging installed-size proxies totaling
38,704,222 bytes are in `evidence/storage-built-image/`. Those installed sizes
are package metadata, not compressed costs or proof every package file was
copied. No proprietary AI client or broad firmware set is included. Native
license texts and package metadata accompany the ISO. Complete corresponding
source/distribution review remains pending. The inherited manifest's
`kernel.base_firmware` text describes the earlier bare-base pin; the current
scope/config specify the storage candidate, which contains no firmware.

## Boot observations and rejected evidence

Latest CI: x86 Linux runner, QEMU 8.2.2, q35 TCG, CPU max, 2 vCPUs,
4096 MiB, no NIC, read-only CD-ROM and seven read-only task-owned fixture files.
No host disks/shares/mounts. BIOS and fresh UEFI variables are separate.
Timer starts immediately before launching QEMU. Base response requires root
shell execution of kernel/PID1 checks, including a fixed 0.5-second input delay;
it is not rescue readiness.

| Latest cold trial | Interactive base response | Strict storage readiness | Network |
| --- | ---: | --- | --- |
| BIOS process 1 | 4.268980500 s | failed before storage tests | disabled / unmeasured |
| UEFI process 1 | 7.078839056 s | failed before storage tests | disabled / unmeasured |

Each requested three-run series stopped after the first strict failure.
No median or three-pass storage timing exists. Raw commands/serial/JSON,
image and firmware hashes are in `evidence/storage-validation-strict-failed/`.
SeaBIOS SHA-256:
`1a9ea4f17bcfb27bda5728e2c21d9fa074cf7947b9b4910bb28213a735c96735`;
OVMF CODE SHA-256:
`949bfa5389c4c48582737481e7d24f46b3a16b276ef44c4089a56858c6a0a446`.

The strict helper exercised the actual Toybox chroot help path, which returns
125. It correctly failed instead of proceeding. Local commit `c972dbf`
replaces help with `chroot / /bin/toybox true` inside the disposable guest.
Source checks pass; this corrected command still needs image validation.

Earlier [run 36879008739](https://github.com/undivisible/alpenglow-rescue/actions/runs/36879008739)
reported green markers despite failed commands: Toybox sh lacks `set -e`,
`set --` and `command -v`. Its storage timings are **rejected**. Unmodified
raw data plus revocation remain in `evidence/storage-validation-rejected/`.
Acceptance now requires all seven exact label/block-device PASS lines, tmux,
READY and exit zero, executed by POSIX oksh with errexit. Regression checks
replay the observed false positive and reject incomplete/nonzero results.

The earlier bare-base UEFI failure remains separate. CI's screen showed
Limine refusing a non-relocatable kernel at `0x100000`; serial text/JSON are
in `evidence/storage-first-attempt/`, with the screen retained in CI.
The storage kernel restores EFI/EFI_STUB and relocation; current UEFI base
response is established. The earlier ARM-host stall's exact cause is not
independently proven under identical firmware.

ARM cp.local bare-base BIOS results were 2.015/1.912/1.917 seconds under
QEMU 11.0.2 TCG; they concern a different bare image/platform. Historical
baseline diagnostics reached visible tmux but no valid probe marker. No
baseline/candidate pair has three matched CPU/RAM/firmware/storage/readiness
runs. No speed ratio may be derived from these incompatible observations.

## Safety, resources and next gate

All fixtures are regular CI files attached with QEMU `readonly=on`; the helper
also checks guest read-only flags. XFS uses SATA CD transport with 2048-byte
sectors because QEMU IDE hard disks reject read-only backends. This does not
test SATA hard-disk repair. VirtIO, NVMe and USB appear in the VM configuration;
complete fixture operations remain unproved. Earlier tool-version launches do
not prove LVM/RAID or actual repair. No credentials, auth enrollment, USB
flashing or remote root service is needed or enabled.

Native build: two jobs/CPUs, 553.635 seconds, maximum additional allocation
3,116,153,654 bytes; minimum host/Docker free space
88,216,231,936 / 88,216,043,520 bytes. Corrective packing grew task data by
71,980 KiB. CI retains a 20 GiB floor, 21 GiB early stop and 4 GiB growth cap.
Local heavy jobs remain stopped. Host availability fell to 18,920,000 KiB
during this turn and later rose to 23,552,000,000 bytes. Docker remains at
13,820,731,392 bytes, below the floor. Shared activity changes availability;
no cleanup or reclamation is attributed to this task.

Automatic approval review initially rejected the source push. After the user
directly authorized it, `main` advanced to `57ea38e3963559f9f36941d6c72e9f6bfea92f67`
on 2026-10-03. That commit includes the guest chroot fix, evidence corrections
and LuaJIT migration. No new image has been built from it. The next gate is a
fresh native storage image and strict three-cold-run storage suite for both
firmware types, then networking, firmware and remaining rescue payloads. The
[validation handoff](next-validation.md) specifies the resource and acceptance
checks. No final release or speed claim follows from the source push.

Earlier checkpoints/reserve policies are preserved in
[measurement-history.md](measurement-history.md) as historical observations.
The [feature/license matrix](feature-license-matrix.md) lists remaining gaps.
