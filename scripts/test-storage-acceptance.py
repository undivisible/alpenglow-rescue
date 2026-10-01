#!/usr/bin/env python3
"""Regression for the observed green marker after failed rescue commands."""
import ast
from pathlib import Path
import re

tree=ast.parse(Path(__file__).with_name('bench-fast-base.py').read_text())
function=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='storage_accepts')
scope={'re':re};exec(compile(ast.Module(body=[function],type_ignores=[]),'<acceptance>','exec'),scope)
accepts=scope['storage_accepts']
bad=b'\nset: bad -e\nRESCUE_FIXTURE_PASS AR_ SEC_TYPE="msdos"\nRESCUE_STORAGE_READY_OK\nSTORAGE_SMOKE_EXIT=0\n'
assert not accepts(bad)
passes=[f'RESCUE_FIXTURE_PASS AR_{label} /dev/vda' for label in ('EXT4','BTRFS','XFS','FAT','EXFAT','NTFS','LUKS')]
lines=passes+['RESCUE_TMUX_PASS','RESCUE_STORAGE_READY_OK','STORAGE_SMOKE_EXIT=0']
assert accepts(('\n'+'\n'.join(lines)+'\n').encode())
for missing in range(len(lines)):
    assert not accepts(('\n'+'\n'.join(lines[:missing]+lines[missing+1:])+'\n').encode())
assert not accepts(('\n'+'\n'.join(lines[:-1]+['STORAGE_SMOKE_EXIT=1'])+'\n').encode())
print('storage acceptance: observed false positive and incomplete/nonzero results rejected')
