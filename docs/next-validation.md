# Next acceptance after native storage-1a

The [2026-10-03 storage report](storage-1a-validated.md) establishes a bootable
33,806,336-byte partial ISO (SHA-256
`a21b7b407df7060d04647e88b2d588a5359d1b2ce7ededd3253344da2b0f5908`).
The exact native base came from Rescue `a05898d`; the reviewed small correction
and embedded probe came from `f9ade38`. Alpenglow remains pinned at
`2214bc159355522bbebc61e8e90ca78933a8e1ac`. Three strict synthetic
storage runs passed under BIOS and three under UEFI. This is not full Omarchy
Rescue equivalence or evidence of a fourfold boot improvement.

The next functional increment needs networking and WiFi, audited firmware and
physical storage/network/graphics driver coverage, a usable local graphical
console with serial fallback, Oil and the three AI client executable launch
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
