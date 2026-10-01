#!/usr/bin/env python3
"""Run task-15 fast-base work with a monitored disk floor and owned jobs."""
import argparse
import datetime
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
LABEL='alpenglow-rescue.build=task15-fast-20261001'

def free_bytes(root):
    s=os.statvfs(root)
    return s.f_bavail*s.f_frsize

def allocated_bytes(path):
    result=subprocess.run(['du','-sk',str(path)],text=True,capture_output=True)
    # du can return 1 while still giving a valid aggregate when a compiler
    # removes a .tmp file during traversal. Missing aggregate is a hard error.
    fields=result.stdout.split()
    if not fields or not fields[0].isdigit():
        raise RuntimeError('du did not return an allocation aggregate')
    return int(fields[0])*1024

def stop_owned_job(process):
    try:
        ids=subprocess.check_output(['docker','ps','-q','--filter','label='+LABEL],text=True).split()
        for cid in ids:
            subprocess.run(['docker','stop','--timeout','10',cid],check=True,stdout=subprocess.DEVNULL)
    finally:
        try: os.killpg(process.pid,signal.SIGTERM)
        except ProcessLookupError: pass
        try: process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL)
            process.wait()

def run_stage(stage,command,root=ROOT):
    out=root/'build/evidence'
    out.mkdir(parents=True,exist_ok=True)
    control=out/'fast-build-control.json'
    if not control.exists():
        if free_bytes(root)<36*1024**3:
            raise SystemExit('Need 30 GiB floor + 6 GiB fast-build allowance')
        control.write_text(json.dumps({'start_free_bytes':free_bytes(root),'floor_bytes':30*1024**3,'soft_stop_bytes':int(31.5*1024**3),'budget_bytes':6*1024**3,'source_subbudget_bytes':int(4.5*1024**3),'label':LABEL,'at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
    rules=json.loads(control.read_text())
    if free_bytes(root)<=rules['soft_stop_bytes']:
        raise SystemExit('Stop: approaching 30 GiB hard floor')
    log=out/f'{stage}.log'
    start=time.monotonic(); samples=[]; stopped=None; allocated=0; next_du=0; cleanup_error=None
    with log.open('wb') as f, (out/f'{stage}.disk.jsonl').open('a') as live:
        env=os.environ.copy(); env['ALPENGLOW_BOUNDED_FAST']='1'
        p=subprocess.Popen(command,cwd=root,stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env=env)
        try:
            while p.poll() is None:
                available=free_bytes(root)
                if time.monotonic()>=next_du:
                    path=root/'build/fast-source'
                    if path.exists(): allocated=allocated_bytes(path)
                    next_du=time.monotonic()+20
                sample={'elapsed_seconds':time.monotonic()-start,'free_bytes':available,'source_allocated_bytes':allocated}
                samples.append(sample); live.write(json.dumps(sample)+'\n'); live.flush()
                if available<=rules['soft_stop_bytes']: stopped='Approaching 30 GiB hard floor'
                if rules['start_free_bytes']-available>rules['budget_bytes']: stopped='6 GiB observed-volume growth budget exceeded'
                if allocated>rules['source_subbudget_bytes']: stopped='4.5 GiB generated-source subbudget exceeded'
                if stopped: break
                time.sleep(2)
        except BaseException as exc:
            stopped=f'Supervisor failure: {type(exc).__name__}: {exc}'
        finally:
            if p.poll() is None:
                try: stop_owned_job(p)
                except Exception as exc: cleanup_error=str(exc)
    code=p.wait()
    report={'stage':stage,'command':command,'exit_code':code,'stopped_reason':stopped,'cleanup_error':cleanup_error,'duration_seconds':time.monotonic()-start,'min_free_bytes':min(s['free_bytes'] for s in samples) if samples else free_bytes(root),'max_source_allocated_bytes':max(s['source_allocated_bytes'] for s in samples) if samples else allocated,'samples':samples}
    (out/f'{stage}-resource.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='samples'},indent=2),flush=True)
    print('raw output:',log,flush=True)
    return 1 if stopped or cleanup_error else code

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--stage',required=True)
    parser.add_argument('command',nargs=argparse.REMAINDER)
    a=parser.parse_args()
    if a.command and a.command[0]=='--':a.command=a.command[1:]
    assert a.command
    raise SystemExit(run_stage(a.stage,a.command))
