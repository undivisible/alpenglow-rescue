#!/usr/bin/env python3
"""Resolve requested rescue symbols after the real FAST disables on Linux 7.1.3."""
import json
from pathlib import Path
import re
import shutil
import subprocess

base=Path('/project/vendor/alpenglow/system/backends/appliance')
kernel=Path('/out/linux-7.1.3')
fast=Path('/out/config-fast')
rescue=Path('/out/config-rescue')
fast.mkdir(exist_ok=True); rescue.mkdir(exist_ok=True)
(fast/'.config').write_text((base/'kernel/alpenglow-qemu-minimal.config').read_text()+''.join((base/'kernel'/name).read_text() for name in ['lz4.config','virt.config','fast.config']))
def resolve(path):
    subprocess.run(['make','-j2','ARCH=x86_64','O='+str(path),'olddefconfig'],cwd=kernel,check=True)
resolve(fast)
text=(base/'scripts/build-kernel-fast.sh').read_text()
span=text[text.index('# Profile-specific trimming'):text.index('if [ "${PROFILE}" = "minimal" ]')]
disables=re.findall(r'--disable ([A-Z][A-Z0-9_]*)',span)
subprocess.run([str(kernel/'scripts/config'),'--file',str(fast/'.config'),*sum((['--disable',s] for s in disables),[])],check=True)
resolve(fast)
shutil.copyfile(fast/'.config',rescue/'.config')
subprocess.run([str(kernel/'scripts/kconfig/merge_config.sh'),'-m','-O',str(rescue),str(rescue/'.config'),'/project/kernel/rescue-x86_64.fragment'],cwd=kernel,check=True)
resolve(rescue)
requested=dict(re.findall(r'^CONFIG_(\w+)=(.+)$',Path('/project/kernel/rescue-x86_64.fragment').read_text(),re.M))
actual=dict(re.findall(r'^CONFIG_(\w+)=(.+)$',(rescue/'.config').read_text(),re.M))
missing={name:{'requested':v,'resolved':actual.get(name,'n')} for name,v in requested.items() if actual.get(name,'n')!=v and not (v=='m' and actual.get(name)=='y')}
report={'kernel':'7.1.3','scope':'Kconfig resolution only; no rescue modules/kernel compiled','requested':len(requested),'fast_disable_symbols':len(disables),'mismatches':missing,'fast_config':'build/fast-source/build/native/config-fast/.config','rescue_config':'build/fast-source/build/native/config-rescue/.config'}
Path('/out/rescue-config-resolution.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)
raise SystemExit(1 if missing else 0)
