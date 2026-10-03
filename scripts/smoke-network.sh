#!/usr/bin/oksh
# Disposable QEMU virtual NIC only; no host networking or physical devices.
set -eu
case " $(cat /proc/cmdline) " in *' alpenglow.test-fixtures=1 '*) ;; *) echo 'Synthetic fixture VM required' >&2; exit 1;; esac
/usr/local/bin/rescue-net-up eth0
/bin/busybox ip -4 addr show dev eth0 | /bin/busybox grep -E 'inet 10\.0\.2\.[0-9]+'
# QEMU restrict=on provides DHCP on an isolated subnet but offers no default
# route. Require the guest's connected route; do not imply outside reachability.
/bin/busybox ip -4 route show | /bin/busybox grep -F '10.0.2.0/24 dev eth0'
printf '%s\n' RESCUE_VIRTUAL_DHCP_OK
