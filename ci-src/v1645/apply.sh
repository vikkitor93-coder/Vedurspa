#!/usr/bin/env bash
set -euo pipefail
echo 'd3e504b84bf72c19eac64dae5e62950e91996a6e5eea0cc7307c83f51ddc7af9  ci-src/v1645/new-look.tar.br' | sha256sum -c -
node -e "require('node:fs').writeFileSync('/tmp/v1645-new-look.tar',require('node:zlib').brotliDecompressSync(require('node:fs').readFileSync('ci-src/v1645/new-look.tar.br')))"
python3 - <<'PY'
from pathlib import Path
import tarfile
with tarfile.open('/tmp/v1645-new-look.tar') as archive:
    for member in archive.getmembers():
        assert not member.name.startswith('/') and '..' not in Path(member.name).parts
    archive.extractall('app',filter='data')
PY
patch --batch --fuzz=0 -p0 -d app < app/ci/v1645-new-look.patch
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
for name in ('package.json','package-lock.json'):
    p=root/name
    d=json.loads(p.read_text())
    assert d['version']=='1.6.44',(name,d['version'])
    d['version']='1.6.45'
    if name=='package-lock.json': d['packages']['']['version']='1.6.45'
    else: d['scripts']['test'] += ' && node tests/v1645NewLook.test.mjs'
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=root/'ci/patch_android.py'
s=p.read_text()
assert "'versionCode 51'" in s and "'versionName \"1.6.44\"'" in s
s=s.replace("'versionCode 51'","'versionCode 52'").replace("'versionName \"1.6.44\"'","'versionName \"1.6.45\"'")
s=s.replace('|50|51)', '|50|51|52)').replace(r'1\.6\.44)',r'1\.6\.44|1\.6\.45)')
p.write_text(s)
for p in (root/'tests').glob('*'):
    if p.suffix not in ('.mjs','.ts','.tsx') or p.name=='v1645NewLook.test.mjs': continue
    t=p.read_text().replace('1.6.44','1.6.45').replace(r'1\.6\.44',r'1\.6\.45').replace('versionCode 51','versionCode 52')
    if p.name=='v1636UpdateBadge.test.ts':
        t=t.replace("isNewerRelease({version:'1.6.45'},'1.6.45'), true","isNewerRelease({version:'1.6.46'},'1.6.45'), true")
    if p.name=='v1633SettingsTabs.test.mjs':
        t=t.replace("['general','guide','language','themes','updates']","['general','guide','language','themes','updates','new-look']")
        t=t.replace(r'/grid grid-cols-5 gap-1\.5/',r'/grid grid-cols-6 gap-1/')
        t=t.replace("assert.match(settings,new RegExp('settings-tab-'+name));","assert.match(settings,new RegExp('settings-tab-'+name));")
        # The Settings tab IDs come from one template, not literal new-look markup.
        t=t.replace("'updates','new-look']","'updates']")
        assert "assert.match(settings,/grid grid-cols-6 gap-1/);" in t
        t=t.replace("assert.match(settings,/grid grid-cols-6 gap-1/);",
                    "assert.match(settings,/grid grid-cols-6 gap-1/);\nassert.match(settings,/key: 'new-look', Icon: Map, label: 'New Look'/);\nassert.match(settings,/NewLookMapPanel/);")
    p.write_text(t)
assert (root/'src/components/NewLookMapPanel.tsx').exists()
assert (root/'native-src/is/viktor/vedurspa/NewLookMapPlugin.java').exists()
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1645NewLook.test.mjs
node app/tests/v1633SettingsTabs.test.mjs
test "$(node -p "require('./app/package.json').version")" = '1.6.45'
