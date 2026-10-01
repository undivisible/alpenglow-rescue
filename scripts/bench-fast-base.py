#!/usr/bin/env python3
"""Native direct-kernel boot proof. Console response only, not rescue readiness."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import threading
import time

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--runs',type=int,default=3)
parser.add_argument('--timeout',type=int,default=120)
a=parser.parse_args()
kernel=root/'build/fast-source/build/native/vmlinuz'
assert kernel.is_file()
out=root/'build/bench/native-fast-base-bios'; out.mkdir(parents=True,exist_ok=True)
results=[]
for run in range(1,a.runs+1):
    s=os.statvfs(root)
    if s.f_bavail*s.f_frsize<int(31.5*1024**3): raise SystemExit('Stop: approaching 30 GiB disk floor')
    cmd=['qemu-system-x86_64','-machine','q35,accel=tcg','-cpu','max','-m','4096','-smp','2',
         '-display','none','-serial','stdio','-monitor','none','-no-reboot','-boot','order=n',
         '-device','e1000,romfile=,netdev=net0','-netdev','user,id=net0',
         '-kernel',str(kernel),'-append','quiet console=ttyS0 init=/init']
    log=bytearray(); markers={}; start=time.monotonic()
    p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    def reader():
        while True:
            chunk=os.read(p.stdout.fileno(),65536)
            if not chunk: break
            log.extend(chunk)
            elapsed=time.monotonic()-start
            if 'boot' not in markers and b'Alpenglow boot' in log: markers['boot']=elapsed
            if 'login' not in markers and b'login:' in log: markers['login']=elapsed
            if 'base_console' not in markers and re.search(rb'\nFAST_BASE_READY_OK\r?\n',log): markers['base_console']=elapsed
    t=threading.Thread(target=reader,daemon=True); t.start()
    logged_in=False; next_probe=0; probes=0
    probe=b'test "$(uname -r)" = 7.1.3 && test "$(cat /proc/1/comm)" = dinit && printf "%s%s\\n" FAST_BASE_ READY_OK\n'
    try:
        while time.monotonic()-start<a.timeout and p.poll() is None:
            elapsed=time.monotonic()-start
            if 'login' in markers and not logged_in:
                p.stdin.write(b'root\n'); p.stdin.flush(); logged_in=True; next_probe=elapsed+.5
            if logged_in and elapsed>=next_probe and 'base_console' not in markers:
                p.stdin.write(probe); p.stdin.flush(); probes+=1; next_probe=elapsed+3
            if 'base_console' in markers: break
            time.sleep(.02)
    finally:
        p.terminate()
        try:p.wait(timeout=5)
        except subprocess.TimeoutExpired:p.kill();p.wait()
        t.join(timeout=5)
    (out/f'run-{run}.serial.log').write_bytes(log)
    results.append({'run':run,'command':cmd,'markers_seconds':markers,'probe_attempts':probes,
                    'rescue_ready_seconds':None,'network_ready_seconds':None,
                    'scope':'direct custom kernel with embedded initramfs; BIOS console command proof, not ISO/full rescue comparison'})
    (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results[-1]),flush=True)
print('kernel_sha256',hashlib.sha256(kernel.read_bytes()).hexdigest(),flush=True)
raise SystemExit(0 if all('base_console' in r['markers_seconds'] for r in results) else 1)
