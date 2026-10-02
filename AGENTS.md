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

The subsequent explicit storage-rescue increment uses GitHub Actions for heavy
work, with the same two-job/CPU bound, 20 GiB hard floor, 21 GiB early stop and
4 GiB allocation cap. Local heavy jobs stay stopped below 20 GiB; do not lower
that floor again. Source pushes and temporary CI test artifacts are authorized;
final binary releases and announcements remain unapproved. Fixture disks are
task-owned regular CI files attached read-only in QEMU, never host devices.

The explicit 2026-10-02 LuaJIT migration supersedes owned Python tooling:
use LuaJIT 2.1 / Lua 5.1 for owned build, evidence and benchmark programs.
Keep shell helpers and vendored third-party sources intact. Twenify has CPU
priority: one build job/CPU, a 14 GiB minimum host/Docker floor, and a 15 GiB
early stop for this continuation; retain the 4 GiB growth cap and earlier
checkpoints. Other historical recipes may retain higher reserves. No retry of
the blocked source publication is authorized by this migration. Do not edit
`.gitattributes`; another task owns that change.
