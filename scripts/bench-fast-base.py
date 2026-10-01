#!/usr/bin/env python3
"""Native direct-kernel boot proof. Console response only, not rescue readiness."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import socket
import tempfile
import subprocess
import threading
import time

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--runs',type=int,default=3)
parser.add_argument('--timeout',type=int,default=120)
parser.add_argument('--iso',type=Path)
parser.add_argument('--name',default='native-fast-base')
parser.add_argument('--firmware',choices=['bios','uefi'],default='bios')
parser.add_argument('--fixtures',action='store_true',help='CI synthetic storage readiness test')
parser.add_argument('--probe-script',type=Path,help='Explicit external test script, streamed only into guest RAM')
a=parser.parse_args()
assert not a.fixtures or os.environ.get('CI') == 'true'
assert not a.probe_script or a.fixtures
probe_body=a.probe_script.read_bytes() if a.probe_script else None
def first_file(paths):
    return next(p for p in map(Path,paths) if p.is_file())
if a.firmware == 'uefi':
    firmware=first_file(['/usr/share/OVMF/OVMF_CODE_4M.fd','/opt/homebrew/share/qemu/edk2-x86_64-code.fd'])
    var_template=first_file(['/usr/share/OVMF/OVMF_VARS_4M.fd','/opt/homebrew/share/qemu/edk2-i386-vars.fd'])
else:
    firmware=first_file(['/usr/share/seabios/bios-256k.bin','/usr/share/qemu/bios-256k.bin','/opt/homebrew/share/qemu/bios-256k.bin'])

def capture_screen(path, destination):
    # Only our own QEMU process/socket; keep firmware failure visible.
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as sock:
        sock.settimeout(5); sock.connect(str(path)); stream=sock.makefile('rwb')
        json.loads(stream.readline())
        for command in [{'execute':'qmp_capabilities'},{'execute':'screendump','arguments':{'filename':str(destination)}}]:
            stream.write(json.dumps(command).encode()+b'\n');stream.flush()
            while True:
                result=json.loads(stream.readline())
                if 'return' in result or 'error' in result:break
            if 'error' in result:raise RuntimeError(result['error'])
kernel=root/'build/fast-source/build/native/vmlinuz'
artifact=a.iso.resolve() if a.iso else kernel
assert artifact.is_file()
out=root/'build/bench'/f'{a.name}-{a.firmware}'; out.mkdir(parents=True,exist_ok=True)
results=[]
for run in range(1,a.runs+1):
    s=os.statvfs(root)
    floor_gib = 21 if os.environ.get('ALPENGLOW_FAST_CONTINUATION') == '1' else 31.5
    if s.f_bavail*s.f_frsize<int(floor_gib*1024**3): raise SystemExit('Stop: approaching authorized disk floor')
    cmd=['qemu-system-x86_64','-machine','q35,accel=tcg','-cpu','max','-m','4096','-smp','2',
         '-display','none','-serial','stdio','-monitor','none','-no-reboot','-nic','none']
    qmp_dir=tempfile.TemporaryDirectory(prefix='ar-qmp-')
    qmp=Path(qmp_dir.name)/'qmp.sock'
    cmd+=['-qmp',f'unix:{qmp},server=on,wait=off']
    if a.iso:
        cmd+=['-drive',f'file={artifact},media=cdrom,format=raw,readonly=on','-boot','order=d']
    else:
        cmd+=['-kernel',str(kernel),'-append','quiet console=ttyS0 init=/init']
    if a.firmware=='uefi':
        variables=out/f'run-{run}.vars.fd'
        variables.write_bytes(var_template.read_bytes())
        cmd+=['-drive',f'if=pflash,format=raw,readonly=on,file={firmware}',
              '-drive',f'if=pflash,format=raw,file={variables}']
    else:cmd+=['-bios',str(firmware)]
    if a.fixtures:
        # All regular task-owned fixture files are read-only block backends.
        fixture_types=[('ext4','virtio-blk-pci'),('btrfs','virtio-blk-pci'),('xfs','ide-cd'),
                       ('exfat','nvme'),('ntfs','virtio-blk-pci'),('luks','virtio-blk-pci'),('fat','usb-storage')]
        cmd+=['-device','qemu-xhci,id=fixture-usb']
        for index,(name,device) in enumerate(fixture_types):
            path=root/'build/fixtures'/f'{name}.img';assert path.is_file()
            drive=f'fixture{index}'
            cmd+=['-drive',f'file={path},if=none,id={drive},format=raw,readonly=on']
            options=f'{device},drive={drive}'
            if device=='nvme':options+=f',serial=AR_FIXTURE_NVME_{index}'
            if device=='usb-storage':options+=',bus=fixture-usb.0'
            cmd+=['-device',options]
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
            if 'shell_exec_failure' not in markers and b'login: exec shell' in log:
                markers['shell_exec_failure']=elapsed
            if 'cli_smoke' not in markers and re.search(rb'\nCLI_SMOKE_OK\r?\n',log): markers['cli_smoke']=elapsed
            fixture_labels=('EXT4','BTRFS','XFS','FAT','EXFAT','NTFS','LUKS')
            fixtures_pass=all(re.search(rb'\nRESCUE_FIXTURE_PASS AR_'+label.encode()+rb' /dev/\S+\r?\n',log) for label in fixture_labels)
            if ('storage_rescue' not in markers and fixtures_pass and b'\nRESCUE_TMUX_PASS\r\n' in log
                and re.search(rb'\nRESCUE_STORAGE_READY_OK\r?\n',log) and re.search(rb'\nSTORAGE_SMOKE_EXIT=0\r?\n',log)):
                markers['storage_rescue']=elapsed
    t=threading.Thread(target=reader,daemon=True); t.start()
    logged_in=False; next_probe=0; probes=0;smoke_sent=False
    probe=b'test "$(uname -r)" = 7.1.3 && test "$(cat /proc/1/comm)" = dinit && printf "%s%s\\n" FAST_BASE_ READY_OK\n'
    try:
        while time.monotonic()-start<a.timeout and p.poll() is None:
            elapsed=time.monotonic()-start
            if 'shell_exec_failure' in markers: break
            if 'login' in markers and not logged_in:
                p.stdin.write(b'root\n'); p.stdin.flush(); logged_in=True; next_probe=elapsed+.5
            if logged_in and elapsed>=next_probe and 'base_console' not in markers:
                p.stdin.write(probe); p.stdin.flush(); probes+=1; next_probe=elapsed+3
            if 'base_console' in markers and not smoke_sent:
                command=(b'/usr/local/bin/rescue-smoke-storage; printf "STORAGE_SMOKE_EXIT=%s\\n" "$?"\n' if a.fixtures else
                         b'/bin/toybox --version && /sbin/dinit --version && printf "%s%s\\n" CLI_SMOKE_ OK\n')
                if probe_body:
                    assert b'AR_EXTERNAL_PROBE_END' not in probe_body
                    command=(b"/usr/bin/oksh -s <<'AR_EXTERNAL_PROBE_END'\n"+probe_body+
                             b'\nAR_EXTERNAL_PROBE_END\nprintf "STORAGE_SMOKE_EXIT=%s\\n" "$?"\n')
                p.stdin.write(command)
                p.stdin.flush();smoke_sent=True
            if ('storage_rescue' if a.fixtures else 'cli_smoke') in markers: break
            if a.fixtures and re.search(rb'\nSTORAGE_SMOKE_EXIT=\d+\r?\n',log):break
            time.sleep(.02)
    finally:
        screen_error=None
        try:capture_screen(qmp,out/f'run-{run}.screen.ppm')
        except Exception as exc:screen_error=str(exc)
        p.terminate()
        try:p.wait(timeout=5)
        except subprocess.TimeoutExpired:p.kill();p.wait()
        t.join(timeout=5)
        qmp_dir.cleanup()
    (out/f'run-{run}.serial.log').write_bytes(log)
    results.append({'run':run,'command':cmd,'markers_seconds':markers,'probe_attempts':probes,
                    'rescue_ready_seconds':markers.get('storage_rescue'),'network_ready_seconds':None,
                    'artifact_bytes':artifact.stat().st_size,'artifact_sha256':hashlib.sha256(artifact.read_bytes()).hexdigest(),
                    'firmware':a.firmware,'firmware_sha256':hashlib.sha256(firmware.read_bytes()).hexdigest(),
                    'benchmark_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                    'qemu_version':subprocess.check_output(['qemu-system-x86_64','--version'],text=True).splitlines()[0],
                    'screen_error':screen_error,
                    'external_probe_sha256':hashlib.sha256(probe_body).hexdigest() if probe_body else None,
                    'scope':('storage increment with synthetic read-only fixtures' if a.fixtures else 'base console command proof only')+'; network disabled; no full rescue comparison'})
    (out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
    print(json.dumps(results[-1]),flush=True)
    if ('storage_rescue' if a.fixtures else 'cli_smoke') not in markers:
        break  # Preserve the first failure; do not repeat an identical timeout.
print('artifact_sha256',hashlib.sha256(artifact.read_bytes()).hexdigest(),flush=True)
required='storage_rescue' if a.fixtures else 'cli_smoke'
raise SystemExit(0 if all('base_console' in r['markers_seconds'] and required in r['markers_seconds'] for r in results) else 1)
