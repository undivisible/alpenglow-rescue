# Native virtual Ethernet and tty1 checkpoint — 2026-10-03

This is a **bootable, partially functional rescue candidate**. The whole ISO
is **33,951,744 bytes** (32.38 MiB), SHA-256
`37b4bd27d59993b5842698734d7b8ce09fe1344d0195a45e847615d9258e02ef`.
It adds built-in VirtIO/e1000 Ethernet support, a manual guest DHCP command,
and a local tty1 text login to the prior native storage candidate. It is not
functionally equivalent to Omarchy Rescue.

## Exact source and artifact

| Item | Pin or measured value |
| --- | --- |
| Alpenglow submodule | `2214bc159355522bbebc61e8e90ca78933a8e1ac` |
| Native image source | Rescue `531db961d4bf3eb47ec912461d9e5e1448152d2b` |
| Strict network benchmark source | Rescue `923e243` (source-only serial marker delimiter; image unchanged) |
| [Image build run](https://github.com/undivisible/alpenglow-rescue/actions/runs/37153910855) | `native-storage-1-x86_64` artifact ID `11285466072`, expires 2026-10-17T21:26:32Z |
| [Exact-artifact network validation](https://github.com/undivisible/alpenglow-rescue/actions/runs/37155473115) | `virtual-network-validation-evidence` artifact ID `11286255369`, expires 2026-10-17T21:33:46Z |
| Whole ISO | 33,951,744 bytes; SHA-256 `37b4bd27d59993b5842698734d7b8ce09fe1344d0195a45e847615d9258e02ef` |
| Native kernel | Linux 7.1.3; embedded vmlinuz 29,963,264 bytes; SHA-256 `e997cbdd5c3571c267c11918779ca177ed9830dd4165bd5ab8770c3efdfa0f3d` |
| Resolved kernel config | SHA-256 `ef00fc38ce71a64f50100fcdc1ed52d05e3df07b6977f0992c717095410857dd` |

The signed Alpine package solution remains 87 records, with no new APK or
firmware for this increment. Existing Busybox 1.37.0-r30 (GPL-2.0-only)
provides `udhcpc`, `ip`, `ifconfig` and `route`; its package metadata reports
813,480 installed bytes, which is not an ISO byte delta. The manual guest
`rescue-net-up eth0` command invokes it and writes only the guest's resolver
file. A new dinit service starts a local tty1 getty alongside the serial
getty. The resolved kernel config has `CONFIG_PACKET`, `CONFIG_NETDEVICES`,
`CONFIG_VIRTIO_NET`, `CONFIG_NET_VENDOR_INTEL` and `CONFIG_E1000` built in.
The new native vmlinuz is 167,936 bytes larger than the validated storage-1a
reference, and the whole ISO is 145,408 bytes larger.

## Cold-boot method and results

Each run starts a fresh `qemu-system-x86_64` process; elapsed time starts
immediately before spawning it. Ubuntu 24.04 QEMU 8.2.2 used q35 TCG,
CPU `max`, one vCPU, 4096 MiB, a read-only ISO and fresh UEFI variables per
UEFI boot. Storage runs attached seven task-owned regular-file fixtures
read-only and used `-nic none`. Network runs had no fixture disks and used a
VirtIO NIC on QEMU user networking with `restrict=on`, IPv6 off and no host
forwarding. No host disk was mounted or repaired.

The **storage endpoint** requires the guest's native kernel/PID 1, live chroot
command, tmux session, seven exact read-only fixture PASS lines, READY and
`STORAGE_SMOKE_EXIT=0`. The **separate virtual DHCP/tty1 endpoint** requires
a DHCP lease and 10.0.2.0/24 connected route, `RESCUE_VIRTUAL_DHCP_OK`,
`NETWORK_SMOKE_EXIT=0`, and an exact whole-line `TTY1_COMMAND_OK` sent by a
command typed into tty1 through QMP's virtual keyboard. The tty1 command
redirects its marker to the serial port for unambiguous automated proof.

| Firmware | Run | Strict storage readiness | Virtual DHCP + tty1 readiness |
| --- | ---: | ---: | ---: |
| BIOS | 1 | 10.323 s | 4.734 s |
| BIOS | 2 | 10.306 s | 4.612 s |
| BIOS | 3 | 10.437 s | 4.618 s |
| UEFI | 1 | 13.717 s | 7.552 s |
| UEFI | 2 | 13.812 s | 7.595 s |
| UEFI | 3 | 13.858 s | 7.543 s |
| **Median** | | **10.323 s BIOS / 13.812 s UEFI** | **4.618 s BIOS / 7.552 s UEFI** |

All 12 downloaded serial logs independently pass the strict LuaJIT acceptance
functions. The six network runs each contain the QEMU 10.0.2.15 lease,
connected route, DHCP marker, exit 0 and tty1 command marker. BIOS QMP screen
captures show the local tty1 login and typed command. The QMP UEFI capture
can occur before full screen repaint; its serial command marker remains the
success criterion. A guest DHCP lease on this restricted subnet proves
neither external reachability nor automatic physical networking.

## Failed probes and resource limits

The first fresh [image run 37152017629](https://github.com/undivisible/alpenglow-rescue/actions/runs/37152017629)
used a default-route assertion. QEMU `restrict=on` supplied a lease and
connected route but no default route, so the network smoke exited 1. The
embedded test was corrected without adding a route or claiming off-box
connectivity. The next image run passed DHCP/route/exit 0, but its benchmark
looked for the tty1 marker on a whole serial line while the serial prompt
preceded it. The source-only benchmark change emits a newline first. The
successful exact-artifact validation then passed three cold boots per
firmware mode. The image-build workflow's overall conclusion is failure
because it ran the earlier benchmark; the later exact-artifact workflow is
green against the same ISO hash. Both earlier failure logs remain in the raw
evidence.

The guarded one-job build lasted **1137.79 s**. Its monitor recorded minimum
free host/Docker bytes **88,114,298,880 / 88,144,850,944** and maximum
additional allocation **3,213,659,481 bytes**, under the 4 GiB cap. The
downloaded ISO was independently size and SHA-256 checked. The small durable
record at [`evidence/virtual-network-1-validated-20261003/`](../evidence/virtual-network-1-validated-20261003/)
contains the manifest, resolved kernel config, package/license inventory,
monitor, six storage and six network result JSONs, raw serial logs and
compressed QMP screens. The binary ISO stays in ignored `build/` and a
time-limited CI artifact; no binary release was published.

## Limits of this checkpoint

The checksum-verified official Omarchy Rescue `v2026.09.30.1` release is
1,954,578,432 bytes, SHA-256
`b812a848e93bc5526094a8165fba8564e9211a7e86859faba2fd525b6bcd82f1`.
The upstream README's roughly 1.8 GB rescue-only and 6.6 GB installer
figures are estimates, separate from the release measurement. This partial
candidate is below 500 MB; a **complete equivalent below 500 MB is not
demonstrated**. No matched upstream three-run rescue-readiness baseline exists
for these CPU/RAM/firmware/storage/endpoint settings, so there is no supported
fourfold boot claim. ARM-host local QEMU diagnostic timings are not included
in the CI medians.

Physical Ethernet and WiFi/firmware, broader storage and graphics drivers,
kmscon, Oil, Claude Code/Codex/OpenCode executable launch, phone login
helpers, full rescue workflows, real repair and a corresponding-source /
distribution audit remain open. No physical disk access, authentication
enrollment, remote root service, USB flash, binary release or social post was
part of this checkpoint.
