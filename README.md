# Alpenglow Rescue

A separate rescue-image project based on pinned
[Alpenglow](https://github.com/tschk/alpenglow), inspired by
[Omarchy Rescue](https://github.com/crmne/omarchy-rescue).

The current **partial storage candidate is 33,658,880 bytes**. It boots to an
interactive shell under BIOS and UEFI in CI. Its custom Linux 7.1.3 kernel
contains restored storage/filesystem/EFI support and signed Alpine storage
tools, preserving Alpenglow's Zig init, dinit and embedded LZ4 root.
It has **not passed the strict filesystem/LUKS/tmux fixture suite**. Networking,
audited firmware coverage, Oil, AI clients and several rescue helpers remain
missing. This is not a validated upstream equivalent.

The development goals are a complete compressed bootable image under
500,000,000 bytes and interactive rescue readiness in one-quarter the matched
baseline time. **Neither complete-product goal is demonstrated.** The official
baseline is checksum-verified at 1,954,578,432 bytes, but no matched valid
three-run readiness comparison exists. Upstream's ~1.8 GB rescue-only and
~6.6 GB installer figures are README estimates. No release or tweet is made.

See the [current measurement report](docs/measurement-report.md),
[feature/license matrix](docs/feature-license-matrix.md),
[storage increment](docs/storage-increment.md), and
[benchmark protocol](docs/benchmark-method.md). Earlier prototypes and the
bare-base proof remain in the [historical report](docs/measurement-history.md).

The latest tested artifact is from
[run 36883059485](https://github.com/undivisible/alpenglow-rescue/actions/runs/36883059485)
at source `4602cc54681f858e1388661f7aebda4754306ae1`; SHA-256
`2dd28a8cc383ef347879887b4e97c99a1f7e434a63ef52333b246eca498c87af`.
Its strict probe failed correctly at Toybox's help exit status. A local fix
uses an actual guest chroot command; that fix has not been image-tested.

The Alpenglow submodule stays at `2214bc159355522bbebc61e8e90ca78933a8e1ac`.
Original Alpenglow checkouts and WIP remain untouched. The corrective candidate
reuses the compiled native kernel and adds a small supplemental initramfs for
oksh, terminfo and the probe. No Alpine kernel is imported. The normal source
recipe now incorporates those corrections before compression; that exact
revised recipe still needs a successful image test.

The manual `Native fast-base image` workflow selects `storage-1` to compile
this increment. `Validate existing storage artifact` verifies and tests an
exact CI image, optionally applying the small corrective layer. Build jobs/CPUs
are now bounded to one. The authorized continuation uses a 14 GiB
host/Docker floor, 15 GiB early stop and 4 GiB growth cap; its initial
checkpoint requires 18 GiB on both filesystems. Historical recipes may
retain higher reserves. Local heavy work remains paused.
Tests use only task-owned regular-file fixtures attached read-only to
network-disabled QEMU. No real host disks, USB flashing, authentication,
credentials or remote root services are used.

Local source checks:

```sh
git submodule update --init
luajit scripts/prepare-fast-base.lua --check
luajit scripts/test-recipes.lua
```

Owned orchestration, monitoring, metadata and benchmark programs use
**LuaJIT 2.1 with Lua 5.1 syntax**. Shell rescue helpers remain shell scripts;
vendored Alpenglow and other third-party software are unchanged. The native
storage package inventory already has no Python. The redundant direct Python
request was removed from the historical full-image recipe, but Borg can still
pull Python transitively. Build-only LuaJIT tooling adds no runtime package to
the native image. See [migration scope and tests](docs/luajit-migration.md).

The Lua migration passes local tooling tests; Linux CI and a newly built image
have not been run. Existing image sizes and boot observations above predate it.

Project and Alpenglow-derived sources use MPL-2.0. Native binaries and signed
APK dependencies retain their own licenses. Exact package versions, license
metadata and source recipe commits accompany the CI image; complete
corresponding-source and distribution review remain requirements before a final
release. Omarchy Rescue's MIT notice is preserved in `licenses/`.
