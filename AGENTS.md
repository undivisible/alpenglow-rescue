# Alpenglow Rescue

Keep the Alpenglow submodule pinned. Do not import uncommitted files from other
checkouts. Build in this project's `build/`, with at most two jobs/CPUs. Check
host and container disk headroom before large work; stop below 20 GiB free.

Never mount host disks, flash USB media, enroll authentication, start a remote
root shell, publish binaries, or post announcements as part of build/tests.
Use synthetic fixtures and read-only diagnostics. Measure the whole bootable
artifact and interactive command response, not a login prompt alone. Keep
firmware, console, and network milestones distinct. No size or speed claim
without raw measurements and an identically configured verified baseline.
