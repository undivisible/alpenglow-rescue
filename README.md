# Alpenglow Rescue

A separate rescue-image project based on pinned
[Alpenglow](https://github.com/tschk/alpenglow), inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

The current **partial storage, virtual Ethernet and tty1 candidate is
33,951,744 bytes** (whole ISO, SHA-256
`37b4bd27d59993b5842698734d7b8ce09fe1344d0195a45e847615d9258e02ef`).
It passed three cold BIOS and three cold UEFI storage boots: guest chroot,
tmux and non-writing checks on seven synthetic read-only ext4, Btrfs, XFS,
FAT, exFAT, NTFS and LUKS fixtures. Median strict storage readiness was
**10.323 s BIOS / 13.812 s UEFI**. Six separate cold boots proved DHCP on a
restricted QEMU virtual subnet and a command typed at the local tty1 console:
median **4.618 s BIOS / 7.552 s UEFI** for that separate endpoint. Tests used
x86_64 QEMU TCG, one vCPU and 4096 MiB. This is a **partially validated
rescue image**, not an upstream equivalent or hardware repair proof.

The image was compiled in [run 37153910855](https://github.com/undivisible/alpenglow-rescue/actions/runs/37153910855)
from project `531db961d4bf3eb47ec912461d9e5e1448152d2b` and validated with
the strict tty1 marker correction in [run 37155473115](https://github.com/undivisible/alpenglow-rescue/actions/runs/37155473115)
at project `923e243`. The Alpenglow submodule remains
`2214bc159355522bbebc61e8e90ca78933a8e1ac`. The
[full test report](docs/virtual-network-console-validated.md) and
[`evidence/virtual-network-1-validated-20261003/`](evidence/virtual-network-1-validated-20261003/)
retain the exact hash, source, kernel config and 12 raw cold-run receipts.
The earlier [33,806,336-byte storage checkpoint](docs/storage-1a-validated.md)
remains a separate historical result. The ignored local
`build/candidate-37153910855/` holds the downloaded current ISO.

The development goals are a complete compressed bootable image under
500,000,000 bytes and interactive rescue readiness in one-quarter the matched
upstream time. **Neither complete-product goal is demonstrated.** Off-box
networking, WiFi, audited firmware/physical driver coverage, graphical
console/kmscon, Oil, the three AI clients, phone login helpers and full rescue
workflows remain incomplete. The checksum-verified official Omarchy Rescue
`v2026.09.30.1` release is 1,954,578,432 bytes; its README's roughly 1.8 GB
rescue-only and 6.6 GB installer figures are estimates. There is no matched
three-run upstream rescue-readiness baseline, so no fourfold claim is made.
No binary release or social post has been made.

See the [feature/license matrix](docs/feature-license-matrix.md),
[next acceptance gates](docs/next-validation.md),
[benchmark protocol](docs/benchmark-method.md) and
[measurement history](docs/measurement-report.md). Original Alpenglow
checkouts and WIP remain untouched. No host disks, USB flashing, credentials,
authentication enrollment or remote root services are used in tests.

The manual `Native fast-base image` workflow selects `storage-1` to compile
the native increment. `Validate existing virtual network artifact` verifies
and tests an exact ISO without recompiling it. The older `Validate existing
storage artifact` workflow preserves the storage-1a checkpoint.
Build jobs/CPUs are bounded to one. The authorized continuation uses a 14 GiB
host/Docker hard floor, 15 GiB early stop and 4 GiB growth cap; higher
step-specific guards still apply. Twenify has CPU priority.

Local source checks:

```sh
git submodule update --init
luajit scripts/prepare-fast-base.lua --check
luajit scripts/test-recipes.lua
```

Owned orchestration, monitoring, metadata and benchmark programs use LuaJIT
2.1 with Lua 5.1 syntax. Shell rescue helpers remain shell scripts. Project
and Alpenglow-derived sources use MPL-2.0; native binaries and signed Alpine
packages retain their own licenses. The current image has 87 signed package
records with complete license metadata, but a corresponding-source and
distribution audit is still required before a final binary release. Omarchy
Rescue's MIT notice is preserved in `licenses/`.
