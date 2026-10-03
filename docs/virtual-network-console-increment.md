# Virtual Ethernet and tty1 increment

The validated storage-1a ISO remains the 33,806,336-byte reference artifact.
This increment was built as a 33,951,744-byte ISO and passed separate strict
storage and virtual DHCP/tty1 guest probes. It remains a partial rescue
system; see the [validation report](virtual-network-console-validated.md).

The preceding storage kernel had `CONFIG_NET=y` and `CONFIG_INET=y`, but
`CONFIG_NETDEVICES` and `CONFIG_PACKET` are disabled. It already has built-in
VT, VGA/framebuffer console, PS/2 keyboard, generic HID and USB HID support.
The rootfs starts a serial getty only. This increment requests built-in packet
sockets, VirtIO Ethernet and Intel e1000, and starts a separate local tty1
getty. It does not add wireless, physical Ethernet families, DRM/kmscon or
firmware; those remain required for broad hardware parity.

The previously signed Alpine payload includes Busybox 1.37.0-r30 (813,480
installed bytes as package metadata, GPL-2.0-only) with DHCP, `ip`, route and
interface applets. The source change adds no APK package or firmware. Its
additional payload is three short guest scripts and one dinit service; the
native vmlinuz grew 167,936 bytes and the whole ISO grew 145,408 bytes over
the validated storage-1a artifact. The manual
`rescue-net-up eth0` command configures the selected guest interface via DHCP
and writes the guest resolver file. Nothing listens for remote access.

The dedicated benchmark attaches a VirtIO NIC to QEMU user networking with
`restrict=on` and no host forwarding, using the same one-vCPU, 4096 MiB,
q35/TCG configuration as the storage suite. In the first fresh image,
QEMU provided a 10.0.2.15 DHCP lease but no default router, and the original
default-route assertion failed. The corrected probe requires the synthetic
fixture boot flag and checks the 10.0.2.x DHCP address plus its connected
10.0.2.0/24 route. QMP sends a command through the virtual keyboard at
tty1; success requires its marker on the serial port as well as DHCP and a
zero shell exit. BIOS and UEFI results are separate. This proves local virtual
DHCP on an isolated virtual subnet and console input only, not external
reachability, WiFi, real hardware support or complete rescue readiness.
