#!/usr/bin/env bash
set -euo pipefail
base64 -d ci-src/v1639/infohub.patch.br.b64 > /tmp/v1639.patch.br
echo '763dc9bcbca66e55a10338a1d6bef5c22a7916303249a4e6bbe2ec192187716c  /tmp/v1639.patch.br' | sha256sum -c -
node -e "const f=require('fs'),z=require('zlib');f.writeFileSync('/tmp/v1639.patch',z.brotliDecompressSync(f.readFileSync('/tmp/v1639.patch.br')))"
patch --batch -p1 -d app < /tmp/v1639.patch
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
for name in ('package.json','package-lock.json'):
 p=root/name;d=json.loads(p.read_text());assert d['version']=='1.6.38';d['version']='1.6.39'
 if name=='package-lock.json':d['packages']['']['version']='1.6.39'
 else:d['scripts']['test']+=' && node tests/v1639InfoHub.test.mjs'
 p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=root/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 45'" in s and "'versionName \"1.6.38\"'" in s
s=s.replace('45)\\b','45|46)\\b').replace(r'1\.6\.38)',r'1\.6\.38|1\.6\.39)')
s=s.replace("'versionCode 45'","'versionCode 46'").replace("'versionName \"1.6.38\"'","'versionName \"1.6.39\"'")
p.write_text(s)
for p in (root/'tests').glob('*'):
 if p.suffix not in ('.mjs','.ts','.tsx'):continue
 s=p.read_text().replace('1.6.38','1.6.39').replace('versionCode 45','versionCode 46').replace(r'1\.6\.38',r'1\.6\.39')
 if p.name=='v1636UpdateBadge.test.ts':
  s=s.replace("isNewerRelease({version:'1.6.39'},'1.6.39'), true","isNewerRelease({version:'1.6.40'},'1.6.39'), true")
 if p.name=='v1637Compliance.test.tsx':
  s=s.replace("assert.match(m,/SourceAttribution/);assert.match(f,/SourceAttribution/);","assert.match(read('src/components/ForecastInfoDialog.tsx'),/Notkunarskilmálar/);")
  s=s.replace("assert.match(m,/SourceAttribution/); assert.match(f,/SourceAttribution/);","assert.match(read('src/components/ForecastInfoDialog.tsx'),/Notkunarskilmálar/);")
  s=s.replace("assert.match(m,/SourceAttribution/)", "assert.match(read('src/components/ForecastInfoDialog.tsx'),/Notkunarskilmálar/)")
  s=s.replace("assert.match(f,/SourceAttribution/)", "assert.match(read('src/components/ForecastInfoDialog.tsx'),/Upprunaleg heimild/)")
 p.write_text(s)
(root/'tests/v1638StationMapRegression.test.mjs').write_text("""import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const station=read('src/components/StationForecastPanel.tsx');
assert.match(station,/<OfficialStationMapFrame refreshToken=/);
assert.doesNotMatch(station,/<div className="relative flex-1 min-h-0"><OfficialStationMapFrame/);
assert.match(station,/onInfoMetaChange/);
assert.doesNotMatch(station,/SourceAttribution/);
assert.match(read('src/components/OfficialStationMapFrame.tsx'),/official-map-frame/);
assert.match(read('src/components/ForecastInfoDialog.tsx'),/Heimildir og upplýsingar/);
console.log('Veðurspá 1.6.39 Staðaspá regression PASS');
""")
(root/'tests/v1639InfoHub.test.mjs').write_text("""import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const app=read('src/App.tsx'),header=read('src/components/CompactHeader.tsx'),dialog=read('src/components/ForecastInfoDialog.tsx');
assert.match(header,/id="btn-app-info"/);
assert.match(app,/ForecastInfoDialog/);
assert.match(dialog,/Veldu flipa hér fyrir neðan/);
assert.match(dialog,/Upprunaleg heimild/);
assert.equal(JSON.parse(read('package.json')).version,'1.6.39');
console.log('Veðurspá 1.6.39 information modal PASS');
""")
(root/'RELEASE_NOTES_1.6.39.md').write_text("""# Veðurspá 1.6.39 — Consistent information
- White info icon between warning and Refresh in the header of every weather tab.
- One shared dialog for Weather, Aurora/Clouds, Staðaspá, and 4 Maps; source/validity/cache times shown when recorded.
- Removed large inconsistent map attribution overlays, keeping licence and legal notices.
- Preserves original native station map full-height fix, updater, themes, and guides.
- Android versionCode 46.
- Native georeferenced GPS pin for zoomed Staðaspá remains a separate task.
""")
(root/'AI_HANDOFF.md').write_text("""# AI_HANDOFF — Veðurspá 1.6.39
React/Vite/TS Iceland weather app, Capacitor6 Android package is.viktor.vedurspa versionCode46/versionName1.6.39, Go Windows portable launcher.
New: white info icon after warning and before Refresh in CompactHeader; ForecastInfoDialog switches source/forecast/cache info among Weather, Aurora, Local and 4 Maps without navigation. Per-map SourceAttribution overlays removed. Original native Staðaspá frame MUST remain direct flex child of station-map-main; 1.6.37 wrapper collapsed its WebView. New dialog suspends native map while open and resumes on close. No fake source times.
CI reconstructs base 1.6.38, applies incremental code patch, npm lint/test/build, Capacitor Android signed APK version46, Go Windows launcher and full source ZIP; publishes GitHub v1.6.39.
Remaining feature: GPS marker geographically anchored to zoomed original native regional Staðaspá maps needs native georeferencing; not implemented. Preserve warning levels, legal info, cached data, themes, languages, tours, updater. Validate on physical Android.
""")
(root/'BUILD_INFO.md').write_text('# Veðurspá 1.6.39\nAndroid versionCode46, GitHub Actions signs APK and packages PC and source.\n')
(root/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.39\nCI tests, lint, web build, Gradle signing/version verification, Windows build; phone QA pending.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1639InfoHub.test.mjs
node app/tests/v1638StationMapRegression.test.mjs
test "$(node -p "require('./app/package.json').version")" = '1.6.39'
