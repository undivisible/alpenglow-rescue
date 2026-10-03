# Next acceptance after virtual Ethernet and tty1

The [2026-10-03 virtual network/console report](virtual-network-console-validated.md)
establishes a bootable 33,951,744-byte partial ISO (SHA-256
`37b4bd27d59993b5842698734d7b8ce09fe1344d0195a45e847615d9258e02ef`).
The image source is Rescue `531db96` and the strict benchmark source is
`923e243`. Alpenglow remains pinned at
`2214bc159355522bbebc61e8e90ca78933a8e1ac`. Three strict synthetic
storage runs passed under BIOS and three under UEFI; six separate cold boots
passed isolated virtual DHCP plus tty1 command response. This is not full
Omarchy Rescue equivalence or evidence of a fourfold boot improvement.

The next functional increment needs automatic physical Ethernet and WiFi,
audited firmware and physical storage/network/graphics driver coverage, a
usable local graphical console/kmscon with serial fallback, Oil and the three
AI client executable launch
checks, plus chroot, mount and phone helper parity. Credential enrollment,
remote root service activation, real disk repair, USB flashing and real host
disk mounts are outside synthetic validation. Preserve essential rescue
features even if they raise the whole ISO above the size target. Finish the
corresponding-source and license distribution audit before a binary release.

For heavy builds, keep Twenify's CPU priority, one Rescue build job/CPU, and
the established 14 GiB host/Docker hard floor, 15 GiB early stop and 4 GiB
additional-allocation cap; honor any higher step-specific guards. Recheck
headroom and active jobs before starting a new run. Keep source and artifacts
isolated from the original Alpenglow WIP checkout.

The official Omarchy Rescue `v2026.09.30.1` release is checksum-verified at
1,954,578,432 bytes, SHA-256
`b812a848e93bc5526094a8165fba8564e9211a7e86859faba2fd525b6bcd82f1`.
Measure at least three **matched** cold upstream and candidate trials per
firmware with identical QEMU version, CPU, memory, storage, network and a
predefined interactive rescue-readiness endpoint. Keep shell, network and
full readiness times separate. ARM-host emulation and CI x86 TCG results
cannot be combined into a speed ratio. Only report an under-500-MB equivalent
or fourfold speedup if the complete feature and matched benchmark gates pass.
