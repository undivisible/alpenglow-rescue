#!/usr/bin/env python3
"""Cold ISO boots on ARM-host TCG. Serial console instrumentation, no target disk."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import select
import socket
import subprocess
import threading
import time

parser = argparse.ArgumentParser()
parser.add_argument('iso', type=Path)
parser.add_argument('--name', required=True)
parser.add_argument('--firmware', choices=['bios', 'uefi'], default='bios')
parser.add_argument('--baseline', action='store_true')
parser.add_argument('--runs', type=int, default=3)
parser.add_argument('--timeout', type=int, default=240)
args = parser.parse_args()
out = Path('build/bench') / f'{args.name}-{args.firmware}'
out.mkdir(parents=True, exist_ok=True)

class QMP:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.settimeout(15)
        self.s.connect(str(path))
        self.f = self.s.makefile('rwb', buffering=0)
        self.f.readline()
        self.call('qmp_capabilities')
    def call(self, command, arguments=None):
        self.f.write(json.dumps({'execute': command, 'arguments': arguments or {}}).encode() + b'\n')
        while True:
            msg = json.loads(self.f.readline())
            if 'error' in msg:
                raise RuntimeError(msg)
            if 'return' in msg:
                return msg['return']
    def key(self, key):
        self.call('human-monitor-command', {'command-line': 'sendkey ' + key + ' 1'})
        time.sleep(.005)
    def close(self):
        self.f.close(); self.s.close()
    def type(self, value):
        mapping = {' ': 'spc', '=': 'equal', ',': 'comma', '-': 'minus', '/': 'slash',
                   '\n': 'ret', '"': 'shift-apostrophe', "'": 'apostrophe',
                   '\\': 'backslash', '$': 'shift-4', '>': 'shift-dot',
                   '<': 'shift-comma', '&': 'shift-7', '|': 'shift-backslash',
                   ';': 'semicolon', '_': 'shift-minus', ':': 'shift-semicolon',
                   '.': 'dot', '!': 'shift-1', '?': 'shift-slash'}
        for ch in value:
            key = mapping.get(ch, ch.lower())
            if ch.isupper(): key = 'shift-' + key
            self.key(key)

results = []
for run in range(1, args.runs + 1):
    sock = out / f'qmp-{run}.sock'
    sock.unlink(missing_ok=True)
    cmd = ['qemu-system-x86_64', '-machine', 'q35,accel=tcg', '-cpu', 'max', '-smp', '2',
           '-m', '4096', '-display', 'none', '-serial', 'stdio', '-monitor', 'none',
           '-qmp', f'unix:{sock},server=on,wait=off', '-no-reboot',
           '-device', 'e1000,romfile=,netdev=net0', '-netdev', 'user,id=net0',
           '-device', 'qemu-xhci,id=xhci', '-device', 'usb-kbd,bus=xhci.0',
           '-drive', f'file={args.iso.resolve()},media=cdrom,format=raw,readonly=on', '-boot', 'order=d']
    if args.firmware == 'uefi':
        code = Path('/opt/homebrew/share/qemu/edk2-x86_64-code.fd')
        template = Path('/opt/homebrew/share/qemu/edk2-i386-vars.fd')
        variables = out / f'vars-{run}.fd'
        variables.write_bytes(template.read_bytes())
        cmd += ['-drive', f'if=pflash,format=raw,readonly=on,file={code}',
                '-drive', f'if=pflash,format=raw,file={variables}']
    log = bytearray()
    events = []
    start = time.monotonic()
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    markers = {}
    def read_serial():
        while True:
            chunk = os.read(p.stdout.fileno(), 65536)
            if not chunk: break
            log.extend(chunk)
            cleaned = bytes(log).replace(b'\r', b'')
            for key, marker in [('rescue', b'\nRESCUE_READY_OK\n'), ('network', b'\nNETWORK_READY_OK\n')]:
                if key not in markers and marker in cleaned:
                    markers[key] = time.monotonic() - start
    reader = threading.Thread(target=read_serial, daemon=True)
    reader.start()
    qmp = None
    edited = False
    probe_at = 0
    ready = network = None
    try:
        while time.monotonic() - start < args.timeout and p.poll() is None:
            elapsed = time.monotonic() - start
            if qmp is None and sock.exists():
                qmp = QMP(sock)
            if qmp and args.baseline and not edited and elapsed >= (3 if args.firmware == 'bios' else 8):
                # BIOS Syslinux: select basic console, tab to edit, append serial.
                # UEFI GRUB automation is handled separately after observing menu.
                if args.firmware == 'bios':
                    qmp.key('down'); qmp.key('tab')
                    # Syslinux does not consume serial input unless configured.
                    # Keyboard append is done with its ASCII key mapping below.
                    qmp.type(' console=tty0 console=ttyS0,115200')
                    qmp.key('ret')
                    edited = True
                    events.append({'event': 'selected-basic-console-with-serial', 'seconds': time.monotonic()-start})
                else:
                    qmp.key('c')
                    time.sleep(.2)
                    p.stdin.write(b'linux (cd0)/arch/boot/x86_64/vmlinuz-linux-t2 archisobasedir=arch archisosearchuuid=2026-09-30-16-02-38-00 xe.enable_panel_replay=0 initramfs_async=0 omarchy.rescue=tty cow_spacesize=50% nomodeset console=tty0 console=ttyS0,115200\ninitrd (cd0)/arch/boot/x86_64/initramfs-linux-t2.img\nboot\n')
                    p.stdin.flush()
                    edited = True
                    events.append({'event': 'selected-basic-console-with-serial', 'seconds': time.monotonic()-start})
            if not args.baseline:
                edited = True
            # Actively elicit a shell response. Merely seeing a login prompt is
            # insufficient. Identical command checks execute on both images.
            if edited and qmp and elapsed >= probe_at and elapsed > 8:
                qmp.type('cryptsetup --version >/dev/null&&btrfs version >/dev/null&&lsblk >/dev/null&&test -n "$TMUX"&&printf "\\nRESCUE_READY_OK\\n" >/dev/console\n')
                qmp.type('ip -4 addr show scope global|grep -q inet&&ping -c1 -W2 10.0.2.2 >/dev/null&&printf "\\nNETWORK_READY_OK\\n" >/dev/console\n')
                probe_at = time.monotonic()-start + 2
            # Reader timestamps serial arrival even while keyboard probes run.
            ready, network = markers.get('rescue'), markers.get('network')
            if ready is not None and network is not None:
                break
            time.sleep(.05)
        if qmp:
            qmp.call('screendump', {'filename': str((out / f'run-{run}.ppm').resolve())})
    finally:
        if qmp: qmp.close()
        p.terminate()
        try: p.wait(timeout=5)
        except subprocess.TimeoutExpired: p.kill(); p.wait()
        reader.join(timeout=5)
        (out / f'run-{run}.serial').write_bytes(log)
        sock.unlink(missing_ok=True)
    item = {'run': run, 'rescue_ready_seconds': ready, 'network_ready_seconds': network, 'events': events, 'command': cmd}
    results.append(item)
    print(json.dumps(item), flush=True)
    (out / 'results.json').write_text(json.dumps({'iso': str(args.iso), 'bytes': args.iso.stat().st_size,
         'sha256': hashlib.file_digest(args.iso.open('rb'), 'sha256').hexdigest(),
         'firmware': args.firmware, 'runs': results}, indent=2)+'\n')
