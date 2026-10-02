# LuaJIT tooling migration, 2026-10-02

All eleven owned Python scripts (887 lines at checkpoint `571148b`) and six
inline Python blocks have been replaced with LuaJIT-compatible Lua 5.1 code.
The tools require LuaJIT 2.1 explicitly. Guest shell helpers and pinned third-party
source remain unchanged. The earlier chroot correction and strict readiness
rules are preserved. No `.gitattributes` edit belongs to this migration.

| Previous owned Python program | LuaJIT replacement |
| --- | --- |
| prepare-fast-base | prepare-fast-base.lua |
| storage-evidence | storage-evidence.lua |
| resolve-rescue-config | resolve-rescue-config.lua |
| install-clients | install-clients.lua |
| run-bounded-fast / resume-fast-base | Same names with .lua; shared lib/monitor.lua |
| bench / bench-fast-base | Same names with .lua; shared lib/qmp.lua and lib/acceptance.lua |
| test-recipes / test-fast-monitor / test-storage-acceptance | Same names with .lua |
| Inline image/fixture/correction manifest blocks | image-evidence.lua |

The remaining inline checksum extraction uses the existing exact pinned kernel
SHA-256 through shell tools. It no longer downloads a checksum list to parse.
CI installs LuaJIT and invokes the Lua scripts. The historical client builder
uses libarchive's `bsdtar` for extraction, curl for HTTPS, and OpenSSL for the
existing npm SHA512 integrity verification; it does not download or enroll
client credentials during these local tests.

Shared process handling uses LuaJIT FFI to POSIX functions. Child argv values
are passed directly to exec, preserving quoting without shell interpolation.
Exit codes, process groups, timeouts, concurrent pipe I/O and SIGINT/SIGTERM
cleanup are handled explicitly. The supervisor blocks termination signals and
consumes them synchronously, avoiding asynchronous Lua signal callbacks.
Hashing streams through the platform SHA tool instead of loading an ISO into
a Lua string. dkjson 2.11 is vendored unchanged from its author's HTTPS site,
with MIT license and exact SHA-256 in `scripts/lib/vendor/README.md`.

The disk monitor retains owned-container labels, transient disappearing-file
handling, both filesystem checks, the narrow live Docker-exec exit127 fallback,
and fail-closed cleanup. The newly authorized continuation uses one job/CPU,
a 14 GiB hard floor, 15 GiB early stop, and 4 GiB additional growth cap, requiring
18 GiB on both filesystems at its initial checkpoint. It uses a new
`luajit-continuation-control.json`; historical controls and evidence survive.
Historical full-image recipes retain their higher reserves. Twenify has CPU
priority, and no heavy local build or VM was started for this migration.

## Runtime scope

The recorded native storage solution contains 86 APK records and no Python
package. Its guest rescue helpers are shell programs, so the build-only LuaJIT
and JSON module do not enter that image. The explicit `python3` request was
removed from historical `packages.txt`. Borg is still present and depends on
Python; that third-party dependency must remain unless its capability is
deliberately replaced and reviewed. No claim that every hypothetical full
image is Python-free follows from this migration. Vendored source and old
raw evidence may still contain Python references.

## Validation and limits

Local LuaJIT `2.1.1784580905` on ARM macOS passed:

- Syntax checks for owned Lua and shell, unchanged Alpenglow source pin,
  exact dkjson hash, native FAST architecture-span assertions and both recipe
  profiles in memory. No source export or kernel build was performed.
- Seven monitor regressions, including allocation races, missing readings,
  both floors, all growth limits, live Docker probe errors, cleanup and report
  persistence.
- Thirteen runtime/equivalence/error-path tests: literal argv, exit125/127,
  timeout/reaping, binary and 300 KB full-duplex pipes, SHA-256, JSON types/errors,
  every field in the historical 86-package inventory, missing license metadata,
  Kconfig module/builtin resolution, image-integrity failures, real local QMP
  protocol/keyboard/error exchanges and real supervisor SIGTERM cleanup.
- Strict readiness acceptance for LF/CRLF, each missing marker, exit1/125/126/127,
  all retained false-positive logs and both strict-failure logs. A readiness
  marker alone remains insufficient.

The exact command, source-file hashes, observed headroom and remaining gates are
recorded in [migration evidence](../evidence/luajit-migration.json); the
[test transcript](../evidence/luajit-migration-checks.txt) preserves its output.

The QMP fixture uses a task-owned Unix socket, not a VM or external network
service. The sandbox blocked socket creation; the same small test suite passed
through normal scoped execution approval. Temporary test directories contain
only synthetic files and are removed by exact path after successful tests.

The initial broad monitor test mock and a partial-write FFI integer-conversion
bug were caught and corrected before the final passing run. Final review also
removed a remaining `CPUS=2` setting from the historical Toybox builder and
added it to the one-job assertions. Linux FFI/CI,
native kernel packaging, actual QEMU readiness and AI client extraction have
not been rerun. Those remain required integration gates; local tests are not
image acceptance. The historical full-image probe now fails on missing readiness
or an invalid run count instead of returning success without a completed set.

New benchmark commands use one vCPU. Old two-vCPU timings remain historical;
collect a matched baseline before comparison. Original artifact bytes/hashes
are preserved, and no size reduction, rescue completion or speed ratio is
claimed. Publication remains paused; no push retry, final release or tweet
was made for this migration.
