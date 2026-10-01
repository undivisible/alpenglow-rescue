#!/usr/bin/env python3
"""Run only task-15 fast-base work with a monitored disk floor and owned jobs."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import time

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--stage',required=True)
parser.add_argument('command',nargs=argparse.REMAINDER)
a=parser.parse_args()
if a.command and a.command[0]=='--': a.command=a.command[1:]
assert a.command
out=root/'build/evidence'
out.mkdir(parents=True,exist_ok=True)
control=out/'fast-build-control.json'
def free():
    s=os.statvfs(root); return s.f_bavail*s.f_frsize
if not control.exists():
    if free()<36*1024**3: raise SystemExit('Need 30 GiB floor + 6 GiB fast-build allowance')
    control.write_text(json.dumps({'start_free_bytes':free(),'floor_bytes':30*1024**3,'soft_stop_bytes':int(31.5*1024**3),'budget_bytes':6*1024**3,'source_subbudget_bytes':int(4.5*1024**3),'label':'alpenglow-rescue.build=task15-fast-20261001','at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
rules=json.loads(control.read_text())
assert free()>rules['soft_stop_bytes']
log=out/f'{a.stage}.log'
start=time.monotonic(); samples=[]; stopped=None; allocated=0; next_du=0
with log.open('wb') as f:
    env=os.environ.copy(); env['ALPENGLOW_BOUNDED_FAST']='1'
    p=subprocess.Popen(a.command,cwd=root,stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env=env)
    while p.poll() is None:
        available=free()
        if time.monotonic()>=next_du:
            path=root/'build/fast-source'
            if path.exists():
                allocated=int(subprocess.check_output(['du','-sk',str(path)],text=True).split()[0])*1024
            next_du=time.monotonic()+20
        samples.append({'elapsed_seconds':time.monotonic()-start,'free_bytes':available,'source_allocated_bytes':allocated})
        if available<=rules['soft_stop_bytes']: stopped='Approaching 30 GiB hard floor'
        if rules['start_free_bytes']-available>rules['budget_bytes']: stopped='6 GiB observed-volume growth budget exceeded'
        if allocated>rules['source_subbudget_bytes']: stopped='4.5 GiB generated-source subbudget exceeded'
        if stopped:
            ids=subprocess.check_output(['docker','ps','-q','--filter','label='+rules['label']],text=True).split()
            for cid in ids: subprocess.run(['docker','stop','--timeout','10',cid],stdout=subprocess.DEVNULL)
            try: os.killpg(p.pid,signal.SIGTERM)
            except ProcessLookupError: pass
            try: p.wait(timeout=15)
            except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL); p.wait()
            break
        time.sleep(2)
code=p.wait()
report={'stage':a.stage,'command':a.command,'exit_code':code,'stopped_reason':stopped,'duration_seconds':time.monotonic()-start,'min_free_bytes':min(s['free_bytes'] for s in samples) if samples else free(),'max_source_allocated_bytes':max(s['source_allocated_bytes'] for s in samples) if samples else 0,'samples':samples}
(out/f'{a.stage}-resource.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='samples'},indent=2),flush=True)
print('raw output:',log,flush=True)
raise SystemExit(1 if stopped else code)
