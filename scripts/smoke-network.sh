#!/usr/bin/oksh
# Disposable QEMU virtual NIC only; no host networking or physical devices.
set -eu
case " $(cat /proc/cmdline) " in *' alpenglow.test-fixtures=1 '*) ;; *) echo 'Synthetic fixture VM required' >&2; exit 1;; esac
/usr/local/bin/rescue-net-up eth0
/bin/busybox ip -4 addr show dev eth0 | /bin/busybox grep -E 'inet 10\.0\.2\.[0-9]+'
/bin/busybox ip -4 route show default | /bin/busybox grep -F 'default via 10.0.2.2'
printf '%s\n' RESCUE_VIRTUAL_DHCP_OK
