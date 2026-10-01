#!/usr/bin/env python3
"""Record the exact signed APK dependency solution and license/source recipes."""
import hashlib
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
native=root/'build/fast-source/build/native'
evidence=native/'storage-evidence'
packages=[]
for record in (evidence/'apk-installed.txt').read_text().strip().split('\n\n'):
    fields=dict(line.split(':',1) for line in record.splitlines() if len(line)>1 and line[1]==':')
    if 'P' not in fields:continue
    packages.append({'name':fields['P'],'version':fields['V'],'license':fields.get('L'),
                     'origin':fields.get('o'),'installed_bytes':int(fields.get('I',0)),
                     'apk_checksum':fields.get('C'),'aports_commit':fields.get('c'),
                     'homepage':fields.get('U'),
                     'source_recipe_tree':f"https://gitlab.alpinelinux.org/alpine/aports/-/tree/{fields.get('c')}",
                     'source_recipe_origin':fields.get('o')})
packages.sort(key=lambda p:p['name'])
report={'scope':'Signed Alpine v3.23 package solution for storage-1; native kernel/init retained; no AI clients/firmware',
        'signature_verification':'apk default verification; no --allow-untrusted; no package scripts',
        'packages':packages,'licenses_without_metadata':[p['name'] for p in packages if not p['license']],
        'kernel_config_sha256':hashlib.sha256((evidence/'kernel.config').read_bytes()).hexdigest(),
        'source_repository_caveat':'First resolution uses the official v3.23 indexes at build time. Exact versions/build commits recorded; source archiving/distribution audit required before a final release.'}
(evidence/'package-license-inventory.json').write_text(json.dumps(report,indent=2)+'\n')
(evidence/'packages.lock').write_text(''.join(f"{p['name']}={p['version']}\n" for p in packages))
output=root/'build/ci/output';output.mkdir(parents=True,exist_ok=True)
for name in ['package-license-inventory.json','kernel.config','apk-installed.txt','packages.lock','native-core.sha256','repositories.txt']:
    (output/name).write_bytes((evidence/name).read_bytes())
iso=root/'build/ci/iso-root';iso.mkdir(parents=True,exist_ok=True)
(iso/'PACKAGE-LICENSES.json').write_bytes((evidence/'package-license-inventory.json').read_bytes())
# Keep the actual license texts shipped by the pinned native source archives.
licenses=iso/'licenses';licenses.mkdir(exist_ok=True)
for name,source in [('linux-COPYING',native/'linux-7.1.3/COPYING'),
                    ('linux-GPL-2.0',native/'linux-7.1.3/LICENSES/preferred/GPL-2.0'),
                    ('toybox-LICENSE',native/'toybox-LICENSE'),
                    ('dinit-LICENSE',native/'dinit-LICENSE')]:
    if source.is_file():(licenses/name).write_bytes(source.read_bytes())
print(json.dumps({'packages':len(packages),'installed_bytes':sum(p['installed_bytes'] for p in packages),
                  'missing_license_metadata':report['licenses_without_metadata']}))
