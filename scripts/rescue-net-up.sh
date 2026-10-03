#!/usr/bin/oksh
# Bring up one local Ethernet interface on request. No background or remote service.
set -eu
interface=${1:-eth0}
case "$interface" in ''|*[!a-zA-Z0-9_.-]*) echo 'Invalid interface name' >&2; exit 2;; esac
/bin/busybox ip link set "$interface" up
/bin/busybox udhcpc -i "$interface" -n -q -t 3 -T 2 -s /usr/local/bin/rescue-udhcpc
