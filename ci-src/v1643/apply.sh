#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import json
R=Path('app')
p=R/'src/components/ContinuousStationMap.tsx';s=p.read_text()
assert 'https://tile.openstreetmap.org/' in s
s=s.replace('https://tile.openstreetmap.org/','https://geo.vedur.is/geoserver/www/imo_basemap_epsg3857/')
s=s.replace('Veðurstöðvar: Veðurstofa Íslands · Kort: OpenStreetMap','Veðurstöðvar: Veðurstofa Íslands · Grunnkort: Veðurstofa Íslands')
s=s.replace('https://www.openstreetmap.org/copyright','https://geo.vedur.is/')
s=s.replace('© OpenStreetMap contributors','Kortagögn: VÍ, LMÍ, OSM, Natural Earth')
s=s.replace('Only visible standard OSM tiles load','Only visible official Veðurstofa Íslands XYZ tiles load')
p.write_text(s)
p=R/'src/components/DeveloperPanel.tsx';s=p.read_text()
assert 'OpenStreetMap-kortaflísar' in s
p.write_text(s.replace('OpenStreetMap-kortaflísar','XYZ-kortaflísar Veðurstofu Íslands'))
p=R/'tests/v1642Variants.test.mjs';s=p.read_text()
assert '/tile.openstreetmap.org/' in s and '/OpenStreetMap contributors/' in s
s=s.replace('/tile.openstreetmap.org/','/geo\\.vedur\\.is\\/geoserver\\/www\\/imo_basemap_epsg3857/').replace('/OpenStreetMap contributors/','/Kortagögn: VÍ/')
p.write_text(s)
p=R/'tests/v1643OfficialTiles.test.mjs'
p.write_text("""import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=path=>readFileSync(new URL('../'+path,import.meta.url),'utf8');
const map=read('src/components/ContinuousStationMap.tsx');
assert.match(map,/geo\\.vedur\\.is\\/geoserver\\/www\\/imo_basemap_epsg3857/);
assert.doesNotMatch(map,/tile\\.openstreetmap\\.org/);
assert.match(map,/Veðurstöðvar: Veðurstofa Íslands/);
assert.match(map,/onPickStation/);
const modes=read('src/components/DeveloperPanel.tsx');
for(const mode of ['official','regional','continuous'])assert.match(modes,new RegExp(mode));
assert.match(read('src/components/AppSettingsPanel.tsx'),/auto-region-switch-settings/);
console.log('Veðurspá 1.6.43 first-party continuous map tiles and 3-map regression PASS');
""")
for p in (R/'tests').glob('*'):
 if p.suffix not in ('.mjs','.ts','.tsx'):continue
 s=p.read_text().replace('1.6.42','1.6.43').replace('versionCode 49','versionCode 50')
 s=s.replace(r'1\.6\.42',r'1\.6\.43')
 if p.name=='v1636UpdateBadge.test.ts':
  s=s.replace("isNewerRelease({version:'1.6.43'},'1.6.43'), true","isNewerRelease({version:'1.6.44'},'1.6.43'), true")
 p.write_text(s)
for name in ('package.json','package-lock.json'):
 p=R/name;d=json.loads(p.read_text());assert d['version']=='1.6.42'
 d['version']='1.6.43'
 if name=='package-lock.json':d['packages']['']['version']='1.6.43'
 else:d['scripts']['test']+=' && node tests/v1643OfficialTiles.test.mjs'
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=R/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 49'" in s and "'versionName \"1.6.42\"'" in s
s=s.replace("'versionCode 49'","'versionCode 50'").replace("'versionName \"1.6.42\"'","'versionName \"1.6.43\"'")
s=s.replace('|48|49)', '|48|49|50)').replace(r'1\.6\.42)',r'1\.6\.42|1\.6\.43)')
p.write_text(s)
(R/'RELEASE_NOTES_1.6.43.md').write_text("""# Veðurspá 1.6.43 — Official continuous-map basemap
- Continuous Staðaspá developer preview now fetches the official XYZ basemap from geo.vedur.is rather than generic OpenStreetMap tile servers.
- Same standard EPSG:3857 tile indexing and georeferenced weather-station positions; no APK-extracted assets are redistributed.
- Original Staðaspá and delayed regional-switch experiments remain available under Developer Mode, with original map still the default.
- Official basemap contains data attributed by Veðurstofa Íslands to LMÍ, OpenStreetMap, Natural Earth and its own datasets. Source links remain visible.
- Preserves weather timelines, GPS, warnings, in-app updates, guidebook and all other features.
- Continuous map remains experimental: tile availability and touch interaction require physical Android testing.
""")
(R/'AI_HANDOFF.md').write_text("""# AI_HANDOFF — Veðurspá 1.6.43
Package is.viktor.vedurspa, versionCode50/versionName1.6.43. Three-map Developer preview preserved from 1.6.42: official native original Staðaspá (default); native regional hold-to-switch via first-party polygon geometry; continuous standard XYZ tile map with source https://geo.vedur.is/geoserver/www/imo_basemap_epsg3857/{z}/{x}/{y}.png, EPSG:3857. Never copy data, code or image tiles from Stokkur's Veður APK; it was inspected only to understand its offline tile approach.
Map component src/components/ContinuousStationMap.tsx computes Web Mercator tile coordinates and markers from src/utils/stationForecast.ts; original remains src/components/OfficialStationMapFrame.tsx and native-src/.../OfficialInlineMapPlugin.java. Device location not transmitted in tile request. Visible attribution names Veðurstofa Íslands and underlying data providers LMÍ, OpenStreetMap, Natural Earth.
Switch map under Settings -> Developer tools (tap version 7 times first). Settings General toggle Sjálfvirk svæðaskipti controls native regional experiment. Original is default on normal users. Never add non-flex native map wrappers; preserve version 1.6.38 and 1.6.41 layout/GPS fixes.
Build/test: npm install, npm run lint, npm test, npm run build, npx cap add android, npx cap sync android, python3 ci/patch_android.py, cd android && ./gradlew assembleDebug; verify pinned signing cert and versionCode50. Go1.22 Windows package and full source ZIP via hosted GitHub Actions. v1643OfficialTiles.test.mjs verifies official endpoint and modes. Android touch/navigation and real tile server network availability need physical verification. Licence terms for each upstream basemap layer remain applicable.
""")
p=R/'docs/legal/SOURCE_REGISTER.md';p.write_text(p.read_text()+"""
### Continuous Staðaspá official XYZ basemap (v1.6.43)
Official service https://geo.vedur.is/geoserver/www/imo_basemap_epsg3857/{z}/{x}/{y}.png (EPSG:3857, standard XYZ), documented at https://geo.vedur.is. Veðurstofa Íslands states source layers include its own data, Landmælingar Íslands, OpenStreetMap and Natural Earth; layer-by-layer rights must still be respected. No third-party APK raster tiles are copied; app only requests visible official tiles. Station forecast data remains from original Vedur.is Staðaspá and wslinfo.js.
""")
(R/'BUILD_INFO.md').write_text('# Veðurspá 1.6.43\nAndroid versionCode50, official first-party continuous XYZ tile map, Android/Windows/source hosted CI build.\n')
(R/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.43\nCI runs full regressions and official tile/provider smoke test; Android signing and Windows packaging verified by GitHub workflow. Phone QA of external tiles required.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1642Variants.test.mjs
node app/tests/v1643OfficialTiles.test.mjs
test "$(node -p "require('./app/package.json').version")" = '1.6.43'
