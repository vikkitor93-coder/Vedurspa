#!/usr/bin/env bash
set -euo pipefail
base64 -d ci-src/v1642/modifications.patch.gz.b64 > /tmp/v1642-modifications.patch.gz
echo '5f5a1a768e58148a48ad7b448787b15ef6492705f58271637d1b2d0d451bedff  ci-src/v1642/modifications.patch.gz.b64' | sha256sum -c -
echo '1d23b95e6dc5e222c1903d7a01034f69a763a57cedf968164db507ad66898310  ci-src/v1642/newfiles.tar.gz.b64' | sha256sum -c -
gzip -dc /tmp/v1642-modifications.patch.gz > /tmp/v1642-modifications.patch
patch --batch --fuzz=0 -p1 -d app < /tmp/v1642-modifications.patch
base64 -d ci-src/v1642/newfiles.tar.gz.b64 | tar -xzf - -C app
python3 app/ci/generate_official_map_auto.py
python3 - <<'PY'
import json
from pathlib import Path
root=Path('app')
for name in ('package.json','package-lock.json'):
 p=root/name
 d=json.loads(p.read_text())
 assert d['version']=='1.6.41',(name,d['version'])
 d['version']='1.6.42'
 if name=='package-lock.json':d['packages']['']['version']='1.6.42'
 else:d['scripts']['test']+=' && node --import tsx tests/v1642MapExperiences.test.tsx'
 p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=root/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 48'" in s and "'versionName \"1.6.41\"'" in s
s=s.replace("'versionCode 48'","'versionCode 49'").replace("'versionName \"1.6.41\"'","'versionName \"1.6.42\"'")
s=s.replace('|47|48)', '|47|48|49)').replace(r'1\.6\.41)',r'1\.6\.41|1\.6\.42)')
p.write_text(s)
for p in (root/'tests').glob('*'):
 if p.name=='v1642MapExperiences.test.tsx' or p.suffix not in ('.mjs','.ts','.tsx'):continue
 s=p.read_text().replace('1.6.41','1.6.42').replace(r'1\.6\.41',r'1\.6\.42').replace('versionCode 48','versionCode 49')
 if p.name=='v1640GpsGuide.test.mjs':
  # v1.6.41 correctly removed CSS positioning of first-party weather markers.
  s=s.replace('assert.match(gps,/getComputedStyle\\(c\\)\\.position/);','assert.doesNotMatch(gps,/c\\.style\\.position/);')
  s=s.replace('assert.match(gps,/getComputedStyle\\(container\\)/);','assert.doesNotMatch(gps,/container\\.style\\.position/);')
 if p.name=='v1636UpdateBadge.test.ts':
  s=s.replace("isNewerRelease({version:'1.6.42'},'1.6.42'), true", "isNewerRelease({version:'1.6.43'},'1.6.42'), true")
 p.write_text(s)
print('Veðurspá 1.6.42 CI overlay applied; original map remains default')
PY
python3 -m py_compile app/ci/patch_android.py app/ci/generate_official_map_auto.py
node app/tests/v1635HeaderWarning.test.mjs
node app/tests/v1640GpsGuide.test.mjs
node app/tests/v1641StationAlignment.test.mjs
test "$(node -p "require('./app/package.json').version")" = '1.6.42'