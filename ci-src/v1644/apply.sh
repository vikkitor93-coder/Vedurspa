#!/usr/bin/env bash
set -euo pipefail
cat ci-src/v1644/part*.b64 > /tmp/vedurspa1644.b64
test "$(wc -c < /tmp/vedurspa1644.b64)" -eq 9792
base64 -d /tmp/vedurspa1644.b64 > /tmp/vedurspa1644.patch.br
echo 'c923d72557148220f281f73e5ad0ca4c7d71a2296ccd065c00490ee25d50f4b2  /tmp/vedurspa1644.patch.br' | sha256sum -c -
node -e "require('node:fs').writeFileSync('/tmp/vedurspa1644.patch',require('node:zlib').brotliDecompressSync(require('node:fs').readFileSync('/tmp/vedurspa1644.patch.br')))"
patch --batch --fuzz=0 -p2 -d app < /tmp/vedurspa1644.patch
python3 - <<'PY'
from pathlib import Path
import json
R=Path('app')
(R/'tests/v1644ProviderMigration.test.ts').write_text(r'''import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {legacyProductSources,resolveProductImage} from '../src/utils/providerSources';
import {parseWeatherForecast,parseAuroraForecast,WEATHER_CATEGORIES,CLOUD_CATEGORIES} from '../src/utils/vedurDirectClient';
const read=(file:string)=>readFileSync(new URL('../'+file,import.meta.url),'utf8');
const weather=read('tests/fixtures/weather.html'),aurora=read('tests/fixtures/aurora.html');
const oldWeather=legacyProductSources('/vedur/spar/thattaspar');
assert.equal(oldWeather[0],'https://eldri.vedur.is/vedur/spar/thattaspar');
assert.equal(oldWeather[1],'https://www.vedur.is/vedur/spar/thattaspar');
for(const category of WEATHER_CATEGORIES){
  const forecast=parseWeatherForecast(weather,category.id,'2026-09-19T15:00:00Z',oldWeather[0]);
  assert.ok(forecast.frames.length>50,category.id);
  assert.ok(forecast.frames.every(frame=>frame.imageUrl.startsWith('https://eldri.vedur.is/photos/')),category.id);
}
for(const category of CLOUD_CATEGORIES){
  const forecast=parseAuroraForecast(aurora,category.id,'2026-09-19T15:00:00Z',legacyProductSources('/vedur/spar/nordurljos/')[0]);
  assert.ok(forecast.frames.length>20,category.id);
  assert.ok(forecast.frames.every(frame=>frame.imageUrl.startsWith('https://eldri.vedur.is/photos/')),category.id);
}
assert.equal(resolveProductImage('https://www.vedur.is/photos/test.gif',oldWeather[0]).href,'https://eldri.vedur.is/photos/test.gif');
assert.equal(resolveProductImage('https://spakort.vedur.is/kort/uwc-ig/test.jpg',oldWeather[0]).hostname,'spakort.vedur.is');
assert.throws(()=>resolveProductImage('https://evil.example.org/any.gif',oldWeather[0]));
assert.throws(()=>legacyProductSources('//evil.example.org'));
assert.throws(()=>legacyProductSources('/../../evil'));
const native=read('src/utils/nativeNetwork.ts');
assert.match(native,/getForecastPageFromSources/);
assert.match(native,/if \(!page.isCached\) return page/);
const station=read('src/utils/stationForecast.ts');
assert.match(station,/legacyProductSources\('\/vedur\/spar\/stadaspar\/'\)/);
assert.match(station,/legacyProductSources\('\/wstations\/wslinfo.js\?v=538'\)/);
const official=read('native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java');
assert.match(official,/HOME = "https:\/\/eldri\.vedur\.is\/vedur\/spar\/stadaspar\/"/);
assert.match(official,/eldri\.vedur\.is/);
assert.match(read('native-src/is/viktor/vedurspa/OfficialCachePolicy.java'),/eldri\.vedur\.is/);
assert.match(read('src/components/ContinuousStationMap.tsx'),/geo\.vedur\.is/);
assert.equal(JSON.parse(read('package.json')).version,'1.6.44');
assert.match(read('ci/patch_android.py'),/versionCode 51/);
console.log('1.6.44 provider migration, safe hosts, native Staðaspá and continuous-map regression PASS');
''')
for name in ('package.json','package-lock.json'):
 p=R/name;d=json.loads(p.read_text());assert d['version']=='1.6.43',(name,d['version'])
 d['version']='1.6.44'
 if name=='package-lock.json':d['packages']['']['version']='1.6.44'
 else:d['scripts']['test']+=' && node --import tsx tests/v1644ProviderMigration.test.ts'
 p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=R/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 50'" in s and "'versionName \"1.6.43\"'" in s
s=s.replace("'versionCode 50'","'versionCode 51'").replace("'versionName \"1.6.43\"'","'versionName \"1.6.44\"'")
s=s.replace('|49|50)\\b','|49|50|51)\\b').replace(r'1\.6\.43)',r'1\.6\.43|1\.6\.44)')
p.write_text(s)
for p in (R/'tests').glob('*'):
 if p.name=='v1644ProviderMigration.test.ts' or p.suffix not in ('.ts','.tsx','.mjs'):continue
 s=p.read_text().replace('1.6.43','1.6.44').replace('versionCode 50','versionCode 51').replace(r'1\.6\.43',r'1\.6\.44')
 if p.name=='v1636UpdateBadge.test.ts':
  s=s.replace("{version:'1.6.44'},'1.6.44'), true", "{version:'1.6.45'},'1.6.44'), true")
 p.write_text(s)
(R/'RELEASE_NOTES_1.6.44.md').write_text('''# Veðurspá 1.6.44 — Provider migration repair

Veðurstofa Íslands redesigned vedur.is on 17 November 2026. Existing original weather, cloud, aurora and station forecast pages moved to eldri.vedur.is. A live host probe on 18 November confirms that the old www URLs now return HTTP 404, while legacy pages still return the original map schemas and image data.

- Restores weather, aurora and cloud forecast catalogs from verified first-party legacy pages.
- Restores native Staðaspá WebView, station forecasts and original weather-station metadata.
- Rewrites known original map image paths to their matching official host; still supports the spakort.vedur.is service.
- Strict first-party allowlist and schema validation; valid fresh provider pages win over outdated caches.
- Native Android original map cache and links now use migrated first-party resources.
- Preserves three developer Staðaspá map modes, GPS marker, station popups and original map size.
- Includes isolated provider URL/category tests and read-only live source probe.
- No third-party APK maps or tiles were incorporated.
''')
(R/'AI_HANDOFF.md').write_text('''# AI_HANDOFF — Veðurspá 1.6.44

Android package is.viktor.vedurspa, versionName 1.6.44, versionCode 51. React/Vite/TypeScript frontend, Capacitor 6 native Android WebView, Go 1.22 Windows launcher. This complete source ZIP is authoritative.

Critical provider migration 17 Nov 2026: www.vedur.is redesigned; original forecast, northern-lights pages, native Staðaspá widget, station metadata and basemap GIF returned 404 on the old host and HTTP 200 on eldri.vedur.is as confirmed by live GitHub Action 44405518272 on 18 Nov. Source registry is src/utils/providerSources.ts; strict resource URLs in src/utils/nativeNetwork.ts; parser src/utils/forecastParser.ts; weather and aurora fetch src/utils/vedurDirectClient.ts. getForecastPageFromSources checks validated fresh responses before cache; image URLs are bound to actual legacy source. The new www pages should not be parsed as the old widgets. Source health probe: ci-src/v1644/probe.py in repository build branch, and tests/v1644ProviderMigration.test.ts.

Native map: native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java HOME and regional links point to eldri.vedur.is, OfficialMapDiskCache/OfficialCachePolicy allow safe legacy assets; original station DOM and station markers are unchanged. Preserve GPS coordinate transform and station positioning. Three developer variants official/regional/continuous remain, latter uses official geo.vedur.is XYZ tiles (NOT third-party APK assets). Warning worker feed migrated to legacy host. Native and web external link allowlists adjusted.

Contracts: preserve provider data models, forecast timestamps, offline caches, legal data attribution, languages/themes, guidebook only in Settings, launch-time update check and pulsing badges, APK download progress and native install flow. No user data migrations or new permissions.

Build/test: Node 20 npm install --no-audit --no-fund; npm run lint; npm test; npm run build; python3 ci/emit_licenses.py; npx cap add android; npx cap sync android; python3 ci/patch_android.py; cd android; ./gradlew assembleDebug. Verify apksigner SHA256 273b709d3ed9a5376d9d1f14811c7d1a13c52a04d4266b5a7eeb9a85e9e7841d and package versionCode 51. Windows GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build ci; ZIP includes web assets. CI workflow publishes v1.6.44 latest release and complete-source ZIP. Developer mode: tap Settings version seven times. Tests: v1644 provider migration plus old regression suite.

Risks: physical native Android QA pending; upstream legacy site may be retired eventually; if source fails, do not render stale data as new. Reprobe first-party sources and validate schemas before changing hosts. Rollback to v1.6.43 signed release not straightforward on installed Android due to versionCode monotonic. Next: test live native regions, GPS, three map modes and cloud forecast across categories; monitor provider status and consider new site official APIs when documented.
''')
(R/'BUILD_INFO.md').write_text('# Veðurspá 1.6.44\nAndroid versionCode51, versionName1.6.44. Hosted CI signs APK, Windows package and complete source ZIP.\n')
(R/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.44\nProvider-migration regression and full suite run by GitHub Actions; consult hosted job for actual pass/fail. Live endpoint probe on 18 Nov confirmed old site 404 and legacy site 200, native device QA pending.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1634WarningAuroraSlider.test.mjs
test "$(node -p "require('./app/package.json').version")" = 1.6.44
