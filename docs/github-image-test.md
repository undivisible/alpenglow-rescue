# GitHub-built native base test, 2026-10-01

The corrected GitHub-built native FAST base boots to an interactive shell in
BIOS QEMU. This completes the base boot-proof milestone, not rescue equivalence.
Rescue payload, restored drivers, firmware, Oil and AI clients remain absent.
There is no matched Omarchy baseline result and no 4x speed or complete-rescue
under-500MB claim. No release or tweet was created.

## Exact provenance

- Project source: `ead71e23926b02a046769ada0787efd17bbf39e3`.
- Pinned Alpenglow: `2214bc159355522bbebc61e8e90ca78933a8e1ac`.
- [Successful GitHub run 36865793057](https://github.com/undivisible/alpenglow-rescue/actions/runs/36865793057).
- Artifact `native-fast-base-x86_64`, ID `11164016836`.
- Artifact ZIP: 6,387,982 bytes; SHA-256
  `d60a61735c0c18d45cdecc9a973f810e6cd33d1238676728faf1c9454e430552`.
- Whole bootable ISO: **9,795,584 bytes**; SHA-256
  `f3ed7b265446c4d0a4af92352af61bed8ed0471da3fd7fa9d7300af7f806ba1a`.
- Linux 7.1.3 official archive SHA-256:
  `be41c068e88f5242a19bccdbffbe077b18c47b45f627e2325504b4fab79dd1dc`.

Downloaded ZIP matched the GitHub artifact digest. ISO bytes/hash matched both
the CI manifest and checksum file, and remained unchanged after read-only boots.
The embedded kernel matched the manifest. Decompressing that kernel located
the exact hash-matching LZ4 initramfs; its Zig init, Toybox and dinit hashes also
matched. Root's login shell is `/bin/sh`, and boot starts only the local serial
getty and virtual-filesystem mount unit. No remote root shell is enabled.

CI used pinned official Alpine/Debian images, checksum-verified official Zig
0.16.0 and Limine 12.4.0, and two build jobs. The monitored build took
407.149 seconds, with 2,520,505,086 bytes maximum tracked additional allocation.
Minimum CI host/Docker availability was 88,971,542,528 / 89,082,523,648 bytes.
The 20 GiB floor and 4 GiB cap were maintained. Local compilation was stopped
to avoid duplicate heavy work, with its kernel objects and prior evidence intact.

## Cold BIOS runs

cp.local is ARM64 macOS. QEMU 11.0.2 used x86_64 TCG, q35, CPU `max`,
two vCPUs, 4096 MiB RAM, no NIC, and only the untouched read-only IDE CD-ROM
ISO. Each trial created a fresh QEMU process; host file cache was not flushed.
SeaBIOS SHA-256 is
`ae6f6aa973aaccc143f57aa960fb035fd9de4daee4ad0cd713322f8c259e7650`.

Time begins before QEMU process creation and ends when the interactive shell
emits `FAST_BASE_READY_OK` after checking `uname -r = 7.1.3` and PID1 = dinit.
It includes sending the local root username and a 0.5-second probe delay.
Toybox and dinit version launches then emit a separate CLI smoke marker.

| Run | Login prompt (s) | Interactive base response (s) | CLI smoke |
| --- | ---: | ---: | --- |
| 1 | 1.467736 | 2.015029 | passed |
| 2 | 1.374032 | 1.912369 | passed |
| 3 | 1.363453 | 1.916766 | passed |

Median base response: **1.916766 seconds**. This includes instrumentation;
it is not a hardware boot estimate or rescue/network readiness time. Raw serial
logs and exact commands are in `evidence/ci-base-boot/` and
`evidence/corrected-ci-base.json`. The logs prove Toybox 0.8.11 and dinit 0.19.2.

One separate UEFI trial started the DVD boot path but produced no serial
Alpenglow/login/readiness marker within 60 seconds. Its cause is unresolved.
UEFI readiness and network readiness remain unestablished; no BIOS/UEFI values
are mixed or compared with the unmatched Omarchy trials.

## Existing upstream GitHub image

[Upstream run 35064440253](https://github.com/tschk/alpenglow/actions/runs/35064440253)
built potato x86_64 successfully, although its aarch64 desktop job failed and
release publication was skipped. Artifact `10433897762` used source
`373c29c2cbb992e93175c4eea227c228a12a05dd`, distinct from our Alpenglow pin.
Its verified ISO was 28,856,320 bytes, SHA-256
`58119c0bd0a41485b2127713c6191489388ce0429a0822322ee9887a7cb58629`.

That untouched ISO reached a BIOS login prompt at 6.889900 seconds. Root login
succeeded, then shell execution failed because `/etc/passwd` contained the
multiword pathname `/bin/toybox sh`. No interactive readiness was established
in the 45-second diagnostic. The corrected project changes only its generated
source copy to the existing `/bin/sh` symlink; original Alpenglow/WIP is untouched.
The upstream ISO also contains no rescue/AI/Oil payload. These two base images
are not equivalent to the complete Omarchy Rescue tool/driver set.
