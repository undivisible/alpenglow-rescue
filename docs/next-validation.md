# Next native storage acceptance

Checkpoint: Rescue `main` `57ea38e3963559f9f36941d6c72e9f6bfea92f67`,
Alpenglow `2214bc159355522bbebc61e8e90ca78933a8e1ac`. The latest tested
33,658,880-byte ISO predates the guest chroot fix and LuaJIT migration. Its one
BIOS and one UEFI interactive shell response are not storage readiness.

The next image run is the manual `Native fast-base image` workflow with
`increment=storage-1` at this source commit. It validates LuaJIT on Linux,
adapts the pinned Alpenglow source, builds the native kernel and signed APK
storage payload with one build job/CPU, packages the whole BIOS/UEFI ISO, and
records the exact ISO bytes, SHA-256, kernel/config/package licenses and raw
build logs. The fresh recipe contains the real guest chroot command and shell,
terminfo and Toybox links; it does not need the older supplemental correction
workflow. The workflow's configured timeout is 40 minutes.

Before dispatch, leave the currently active local jobs their CPU slot. Recheck
host and Docker free space. The new continuation checkpoint needs at least
18 GiB free on each filesystem, then stops at 15 GiB or after 4 GiB of
additional growth; the package payload and ISO scripts have stricter 21 GiB
guards. Treat the largest applicable guard as the minimum. No local heavy job
or fixture VM is needed to prepare this run. Preserve all prior controls and
raw evidence. Existing task-owned `build/` totals about 2.6 MiB, so it offers
no useful disk reclamation; do not clean unrelated checkouts or caches.

Acceptance requires three fresh QEMU processes under BIOS and three under UEFI,
each with a reset UEFI variable file, q35 TCG, one vCPU, 4096 MiB, no NIC, the
same ISO and seven task-owned regular-file fixtures attached read-only. Record
the command, firmware/image hashes, serial log, screen and elapsed markers for
every run. A valid storage result needs all seven exact fixture PASS labels,
tmux PASS, READY, and `STORAGE_SMOKE_EXIT=0`; failures stop the series and stay
visible. Actual repair, hardware drivers, networking, AI clients and full
upstream rescue parity are separate acceptance gates. No matched upstream
three-run rescue-readiness baseline or fourfold boot claim exists yet.
