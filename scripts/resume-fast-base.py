#!/usr/bin/env python3
"""Explicit continuation: 20 GiB host/guest floor, 4 GiB new allocation cap."""
import argparse
import datetime
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import time

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fast_monitor',Path(__file__).with_name('run-bounded-fast.py'))
monitor=importlib.util.module_from_spec(spec);spec.loader.exec_module(monitor)
GIB=1024**3
FLOOR=20*GIB
SOFT=21*GIB
CAP=4*GIB
IMAGE='debian@sha256:3783cc01769c7b2b1b83a5c5ad96c815348e28ed7da68e2e3687004faa906251'

def checked(args):
    return subprocess.check_output(args,text=True,timeout=15)

def docker_free(container=None):
    if container:
        args=['docker','exec',container,'df','-Pk','/']
    else:
        args=['docker','run','--rm','--pull=never','--platform','linux/amd64','--network','none',
              '--read-only','--cpus=2','--memory=128m','--pids-limit=64',
              '--label','alpenglow-rescue.audit=task15-continuation-20261001',IMAGE,'df','-Pk','/']
    return int(checked(args).splitlines()[-1].split()[3])*1024

def owned_usage():
    ids=checked(['docker','ps','-q','--filter','label='+monitor.LABEL]).split()
    layer=0; available=None
    for cid in ids:
        try:
            layer+=int(checked(['docker','inspect','--size','--format','{{.SizeRw}}',cid]))
            current=docker_free(cid)
            available=current if available is None else min(available,current)
        except subprocess.CalledProcessError:
            # A --rm container can finish between ps, inspect and exec.
            if cid in checked(['docker','ps','-q','--filter','label='+monitor.LABEL]).split(): raise
    return layer,available

def violation(host,guest,allocation_growth,host_drop,guest_drop):
    if min(host,guest)<=SOFT: return 'Approaching 20 GiB host/Docker hard floor'
    if max(allocation_growth,host_drop,guest_drop)>CAP: return '4 GiB continuation allocation/growth cap exceeded'
    return None

def run(stage,command):
    out=ROOT/'build/evidence';out.mkdir(parents=True,exist_ok=True)
    control=out/'fast-continuation-control.json'
    if not control.exists():
        host=monitor.free_bytes(ROOT);guest=docker_free()
        if min(host,guest)<FLOOR+CAP: raise SystemExit('Need 24 GiB on both filesystems before continuation')
        rules={'host_start_free_bytes':host,'docker_start_free_bytes':guest,
               'source_start_allocated_bytes':monitor.allocated_bytes(ROOT/'build/fast-source'),
               'floor_bytes':FLOOR,'soft_stop_bytes':SOFT,'additional_cap_bytes':CAP,
               'at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
               'authorization':'Explicit bounded native continuation; earlier control files preserved.'}
        control.write_text(json.dumps(rules,indent=2)+'\n')
    rules=json.loads(control.read_text())
    guest=docker_free();host=monitor.free_bytes(ROOT)
    start_source=monitor.allocated_bytes(ROOT/'build/fast-source')
    reason=violation(host,guest,max(0,start_source-rules['source_start_allocated_bytes']),
                     max(0,rules['host_start_free_bytes']-host),max(0,rules['docker_start_free_bytes']-guest))
    if reason: raise SystemExit(reason)
    samples=[];stopped=None;cleanup_error=None;next_sample=0;start=time.monotonic()
    log=out/f'{stage}.log'
    with log.open('wb') as f,(out/f'{stage}.disk.jsonl').open('a') as live:
        env=os.environ.copy();env['ALPENGLOW_FAST_CONTINUATION']='1'
        p=subprocess.Popen(command,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env=env)
        try:
            while p.poll() is None:
                host=monitor.free_bytes(ROOT)
                if time.monotonic()>=next_sample:
                    allocated=monitor.allocated_bytes(ROOT/'build/fast-source')
                    layer,owned_free=owned_usage()
                    guest=docker_free() if owned_free is None else owned_free
                    growth=max(0,allocated-rules['source_start_allocated_bytes'])+layer
                    next_sample=time.monotonic()+10
                sample={'elapsed_seconds':time.monotonic()-start,'host_free_bytes':host,
                        'docker_free_bytes':guest,'source_allocated_bytes':allocated,
                        'owned_container_rw_bytes':layer,'additional_allocation_bytes':growth}
                samples.append(sample);live.write(json.dumps(sample)+'\n');live.flush()
                stopped=violation(host,guest,growth,max(0,rules['host_start_free_bytes']-host),
                                  max(0,rules['docker_start_free_bytes']-guest))
                if stopped:break
                time.sleep(2)
        except BaseException as exc:stopped=f'Supervisor failure: {type(exc).__name__}: {exc}'
        finally:
            if p.poll() is None:
                try:monitor.stop_owned_job(p)
                except Exception as exc:cleanup_error=str(exc)
    code=p.wait()
    report={'stage':stage,'command':command,'exit_code':code,'stopped_reason':stopped,'cleanup_error':cleanup_error,
            'duration_seconds':time.monotonic()-start,'min_host_free_bytes':min((s['host_free_bytes'] for s in samples),default=host),
            'min_docker_free_bytes':min((s['docker_free_bytes'] for s in samples),default=guest),
            'max_additional_allocation_bytes':max((s['additional_allocation_bytes'] for s in samples),default=0),'samples':samples}
    (out/f'{stage}-resource.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='samples'},indent=2),flush=True)
    return 1 if stopped or cleanup_error else code

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--stage',required=True)
    parser.add_argument('command',nargs=argparse.REMAINDER);a=parser.parse_args()
    if a.command and a.command[0]=='--':a.command=a.command[1:]
    assert a.command
    raise SystemExit(run(a.stage,a.command))
