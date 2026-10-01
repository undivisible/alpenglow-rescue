# Benchmark protocol

All results are scoped to cp.local: ARM64 macOS, x86_64 QEMU 11.0.2 TCG.
They do not predict x86 hardware, ARM native boot, or KVM performance.

Both ISOs use identical QEMU q35, `-cpu max`, 2 vCPUs, 4096 MiB RAM,
read-only IDE CD-ROM, no target disk, e1000, user-mode private networking,
and the same firmware files. BIOS and UEFI results are separate. Each run
launches a fresh QEMU process; UEFI variable storage is reset from its template.
Host page cache is not forcibly purged, so these are cold guest boots, not
claims about cold host storage. Background builds must finish before timed runs.

Start: immediately before spawning QEMU (`time.monotonic`). End: guest prints
an unambiguous raw serial marker after an interactive tmux shell successfully
runs `cryptsetup --version`, `btrfs version`, and `lsblk`. Probe commands are
identical; keyboard typing plus a two-second gap between probes adds observation
latency, which must be reported. A background serial reader timestamps marker
arrival while the keyboard probe is still being entered. A login prompt or init
banner is insufficient. Readiness does not
include authentication, repair, or agent inference.

The baseline's official basic-console entry is selected and serial console
arguments are appended by guest bootloader input. The release ISO stays byte
for byte unchanged. Menu selection/input time is recorded and included. Use
the candidate's basic console as the corresponding path; do not compare a
trimmed direct-kernel boot with a full upstream ISO firmware boot.

Network milestone: global IPv4 configuration plus a successful ICMP response
from QEMU's private gateway (10.0.2.2). This does not establish Wi-Fi hardware,
external DNS, internet reachability, or a remote service. Failed/timeout boots
remain in raw results and are never converted into favorable speed ratios.

Run at least three valid runs per artifact and firmware, retain all commands,
serial logs, ISO hashes, sizes, and marker timestamps. Report each sample and
median. Claim quarter-time only if matched valid medians establish it. Whole
ISO bytes, including kernel, initramfs, firmware and bootloader, define the
500,000,000-byte goal. Compressed initramfs alone is not the goal artifact.

Development diagnostics while a build is running are excluded from timing
claims. Feature/license gaps and any difference in AI versions remain visible.
