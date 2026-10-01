# Rescue environment

Diagnose read-only first. Do not mount target filesystems, unlock devices,
repair, partition, overwrite, or enroll accounts without a specific user's
request. Never expose a remote root shell automatically. The target may use
LUKS, Btrfs subvolumes, snapper and Limine; inspect its fstab before planning
mounts. This environment has musl, dinit and Alpenglow's Oil package manager.
Do not assume the host is Alpenglow. This is a development candidate.
