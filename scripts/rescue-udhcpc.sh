#!/usr/bin/oksh
# Busybox udhcpc hook; all changes stay inside the booted rescue guest.
set -eu
case "${interface:-}" in ''|*[!a-zA-Z0-9_.-]*) exit 2;; esac
case "${1:-}" in
  deconfig) /bin/busybox ifconfig "$interface" 0.0.0.0 ;;
  bound|renew)
    test -n "${ip:-}" && test -n "${subnet:-}"
    /bin/busybox ifconfig "$interface" "$ip" netmask "$subnet" up
    if test -n "${router:-}"; then
      gateway=${router%% *}
      /bin/busybox route del default 2>/dev/null || true
      /bin/busybox route add default gw "$gateway" dev "$interface"
    fi
    if test -n "${dns:-}"; then
      : > /etc/resolv.conf
      for server in $dns; do printf 'nameserver %s\n' "$server" >> /etc/resolv.conf; done
    fi
    ;;
esac
