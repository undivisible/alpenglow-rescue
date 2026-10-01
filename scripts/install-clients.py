#!/usr/bin/env python3
"""Fetch only official x86_64/musl client payloads, verify npm SHA512, preserve notices."""
import base64
import hashlib
import io
import json
import shutil
from pathlib import Path
import tarfile
import urllib.request

if shutil.disk_usage('.').free < 40 * 1024**3:
    raise SystemExit('Stop: less than 40 GiB host headroom')

pins = json.loads(Path('pins.json').read_text())
root = Path('build/rootfs')
packages = {
    'claude': ('@anthropic-ai/claude-code-linux-x64-musl', pins['claude']['version']),
    'codex': ('@openai/codex', pins['codex']['version'] + '-linux-x64'),
    'opencode': ('opencode-linux-x64-baseline-musl', pins['opencode']['version']),
}
for name, (package, version) in packages.items():
    with urllib.request.urlopen('https://registry.npmjs.org/' + package + '/' + version) as r:
        meta = json.load(r)
    Path(f'build/evidence/{name}-npm.json').write_text(json.dumps(meta, indent=2) + '\n')
    archive = Path('build/downloads') / f'{name}-{version}.tgz'
    if not archive.exists():
        urllib.request.urlretrieve(meta['dist']['tarball'], archive)
    data = archive.read_bytes()
    expected = 'sha512-' + base64.b64encode(hashlib.sha512(data).digest()).decode()
    if expected != meta['dist']['integrity']:
        raise RuntimeError(f'{name}: integrity mismatch')
    dest = root / 'opt' / name
    dest.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as t:
        t.extractall(dest, filter='data')
    if name == 'codex':
        choices = list(dest.glob('**/x86_64-unknown-linux-musl/codex/codex'))
    else:
        choices = list(dest.glob(f'**/bin/{name}')) + list(dest.glob(f'**/bin/{name}.exe'))
    if len(choices) != 1:
        raise RuntimeError(f'{name}: binary not unique: {choices}')
    choices[0].chmod(0o755)
    link = root / 'usr/local/bin' / name
    link.unlink(missing_ok=True)
    link.symlink_to('/' + str(choices[0].relative_to(root)))
    print(f'{name} {version}: {len(data)} compressed bytes, {choices[0].stat().st_size} executable bytes', flush=True)
