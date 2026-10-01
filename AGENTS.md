# Alpenglow Rescue

Keep the Alpenglow submodule pinned. Do not import uncommitted files from other
checkouts. Build in this project's `build/`, with at most two jobs/CPUs. Check
host and container disk headroom before large work; stop below 40 GiB free.

Never mount host disks, flash USB media, enroll authentication, start a remote
root shell, publish binaries, or post announcements as part of build/tests.
Use synthetic fixtures and read-only diagnostics. Measure the whole bootable
artifact and interactive command response, not a login prompt alone. Keep
firmware, console, and network milestones distinct. No size or speed claim
without raw measurements and an identically configured verified baseline.

The specifically authorized 2026-10-01 native fast-base run has a 6 GiB
temporary budget and a 30 GiB hard disk floor (early stop at 31.5 GiB).
This exception does not authorize the full rescue build or publication of
images/benchmarks. Keep other build recipes at the default reserve.

The later explicitly authorized continuation of that cached native fast base
uses a 20 GiB hard floor on both host and Docker, a 21 GiB early stop, and a
4 GiB additional-allocation cap from its new continuation checkpoint. Preserve
earlier monitoring controls and the existing kernel objects. This exception
permits only kernel completion and native base boot proof, not full rescue.
