# Alpenglow Rescue

A separate rescue-image project based on pinned
[Alpenglow](https://github.com/tschk/alpenglow), inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

The current **partial storage candidate is 33,806,336 bytes** (whole ISO,
SHA-256 `a21b7b407df7060d04647e88b2d588a5359d1b2ce7ededd3253344da2b0f5908`).
It passed three cold BIOS and three cold UEFI boots in CI. Each run executed a
guest chroot, launched tmux, and passed non-writing checks on seven synthetic
read-only ext4, Btrfs, XFS, FAT, exFAT, NTFS and LUKS fixtures. Median strict
storage readiness was **10.445 s BIOS** and **13.126 s UEFI**, under x86_64
QEMU TCG with one vCPU, 4096 MiB and no network. This is a **partially validated
rescue image**, not an upstream equivalent or hardware repair proof.

The verified candidate comes from the native compiled base in
[run 37148585459](https://github.com/undivisible/alpenglow-rescue/actions/runs/37148585459)
at project `a05898d`, plus the reviewed small shell/terminfo/probe correction
in [run 37150320698](https://github.com/undivisible/alpenglow-rescue/actions/runs/37150320698)
at project `f9ade38`. The Alpenglow submodule remains at
`2214bc159355522bbebc61e8e90ca78933a8e1ac`. The correction keeps the
same native Linux 7.1.3 kernel, embedded LZ4 root, Zig init, static Toybox and
dinit. The [full test report](docs/storage-1a-validated.md) records exact
hashes, commands and six raw cold-run results; small durable evidence is in
[`evidence/storage-1a-validated-20261003/`](evidence/storage-1a-validated-20261003/).
The ignored local `build/candidate-37150320698/` holds the downloaded ISO.

The development goals are a complete compressed bootable image under
500,000,000 bytes and interactive rescue readiness in one-quarter the matched
upstream time. **Neither complete-product goal is demonstrated.** Networking
and WiFi, audited firmware/physical driver coverage, a local graphical
console, Oil, the three AI clients, phone login helpers and full rescue
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

The manual `Native fast-base image` GitHub workflow selects `storage-1` to
compile the native increment. `Validate existing storage artifact` verifies
and tests an exact CI image, optionally applying the small corrective layer.
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
