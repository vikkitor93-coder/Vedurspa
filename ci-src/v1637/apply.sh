#!/usr/bin/env bash
set -euo pipefail
echo "1fb09a1fa07ba156a35f8f974f3bbbe879b1e14ae51f1db2e208819597bc55d0  ci-src/v1637/core.patch.xz" | sha256sum -c -
echo "e4d66f6f980525b3ecabbfd1b9a469de22e27cd70aeb38a2786ed49bbdd0c423  ci-src/v1637/docs.patch.xz" | sha256sum -c -
mkdir -p app/docs/legal
xz -dc ci-src/v1637/core.patch.xz | patch --batch --fuzz=0 -p1 -d app
xz -dc ci-src/v1637/docs.patch.xz | patch --batch --fuzz=0 -p1 -d app
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
for filename in ('package.json','package-lock.json'):
    path=root/filename
    data=json.loads(path.read_text())
    assert data['version']=='1.6.36',data['version']
    data['version']='1.6.37'
    if filename=='package-lock.json':
        data['packages']['']['version']='1.6.37'
    else:
        data['scripts']['test']+=' && node --import tsx tests/v1637Compliance.test.tsx'
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
path=root/'ci/patch_android.py'
s=path.read_text()
assert "'versionCode 43'" in s and "'versionName \"1.6.36\"'" in s
s=s.replace("'versionCode 43'","'versionCode 44'").replace("'versionName \"1.6.36\"'","'versionName \"1.6.37\"'")
s=s.replace('|42|43)', '|42|43|44)').replace(r'1\.6\.36)',r'1\.6\.36|1\.6\.37)')
path.write_text(s)
for path in (root/'tests').glob('*'):
    if path.suffix not in ('.mjs','.tsx','.ts'):continue
    s=path.read_text().replace('1.6.36','1.6.37').replace('versionCode 43','versionCode 44')
    s=s.replace(r'1\.6\.36',r'1\.6\.37')
    if path.name=='v1636UpdateBadge.test.ts':
        s=s.replace("{version:'1.6.37'},'1.6.37'), true", "{version:'1.6.38'},'1.6.37'), true")
    path.write_text(s)
PY
python3 -m py_compile app/ci/patch_android.py app/ci/emit_licenses.py
test "$(node -p "require('./app/package.json').version")" = '1.6.37'
