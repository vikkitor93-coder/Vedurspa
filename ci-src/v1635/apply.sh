#!/usr/bin/env bash
set -euo pipefail
base64 -d ci-src/v1635/progress-header.patch.br.b64 > /tmp/v1635.patch.br
echo '8e2ed52158f25966b04308212b69e97569b550ae297fc12dabb2291c930891d6  /tmp/v1635.patch.br' | sha256sum -c -
node -e "require('node:fs').writeFileSync('/tmp/v1635.patch',require('node:zlib').brotliDecompressSync(require('node:fs').readFileSync('/tmp/v1635.patch.br')))"
patch --batch --fuzz=0 -p1 -d app < /tmp/v1635.patch
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
for name in ('package.json','package-lock.json'):
    p=root/name
    data=json.loads(p.read_text())
    assert data['version']=='1.6.34', (name,data['version'])
    data['version']='1.6.35'
    if name=='package-lock.json': data['packages']['']['version']='1.6.35'
    else: data['scripts']['test'] += ' && node tests/v1635HeaderWarning.test.mjs && node --import tsx tests/v1635UpdateProgress.test.tsx'
    p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
p=root/'ci/patch_android.py'
s=p.read_text()
assert "'versionCode 41'" in s and "'versionName \"1.6.34\"'" in s
s=s.replace("'versionCode 41'","'versionCode 42'").replace("'versionName \"1.6.34\"'","'versionName \"1.6.35\"'")
s=s.replace('|40|41)', '|40|41|42)').replace(r'1\.6\.34)',r'1\.6\.34|1\.6\.35)')
p.write_text(s)
for p in (root/'tests').glob('*'):
    if p.suffix not in ('.mjs','.ts','.tsx'): continue
    s=p.read_text().replace('1.6.34','1.6.35').replace('versionCode 41','versionCode 42')
    if p.name=='v1634WarningAuroraSlider.test.mjs':
        s=s.replace('assert.match(banner,/weather-warning-emboss/);', 'assert.match(banner,/activeWarnings/);\nassert.doesNotMatch(banner,/weather-warning-emboss/);')
    p.write_text(s)
(root/'RELEASE_NOTES_1.6.35.md').write_text('# Veðurspá 1.6.35 — Download progress and warning icon\n\n- Android APK download progress bar with percentage and megabytes.\n- Header weekday wraps beside date and warnings.\n- Warning icon pulses only for active yellow/orange/red warnings, without numeric badges.\n- Preserves forecast maps, data and settings.\n')
(root/'AI_HANDOFF.md').write_text('''# AI_HANDOFF — Veðurspá 1.6.35
Purpose: Iceland weather app, React/Vite/Capacitor6 for Android, Go Windows launcher. Android package is.viktor.vedurspa, versionCode42, versionName 1.6.35. Current complete source ZIP is authoritative.
Architecture: src/App.tsx; src/components/CompactHeader.tsx, WarningBanner.tsx, AppSettingsPanel.tsx, UpdateDownloadProgress.tsx; src/utils/appUpdate.ts, androidUpdater.ts; ci/patch_android.py, ci/*.go, .github/workflows/build-release.yml.
Contracts/data: preserve saved appSettings format, theme/language options, provider APIs, native AndroidUpdateStatus payloads and manual install flow.
Flows: active warnings render only one severity-colored pulsing icon (no numeric badges); date wraps; native APK download exposes bytes for accessible percentage/MB progress. Maps and data unchanged.
Build/tests: Node20 npm install, npm run lint, npm test, npm run build; npx cap add android && npx cap sync android; python3 ci/patch_android.py; ./android/gradlew assembleDebug; verify apksigner certificate and aapt versionCode42. Windows GOOS=windows GOARCH=amd64 go build in ci and bundle dist. Source ZIP packaged by GitHub Actions.
Developer mode: Settings tap version seven times; diagnostics unchanged. Latest tests: v1635HeaderWarning and v1635UpdateProgress plus full regression via CI. Risks: on-device narrow headers/download progress not yet verified. Rollback: v1.6.34 signed release; Android downgrade may need uninstall. Next: publish v1.6.35, add launch update check and pulsing exclamation badges in v1.6.36.
''')
(root/'BUILD_INFO.md').write_text('# Veðurspá 1.6.35\nVersionCode42; GitHub Actions signs APK and packages PC/source.\n')
(root/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.35\nFocused warning/progress tests followed by CI TypeScript, full regressions, Vite, Android signing and Windows. Check actual run logs.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1635HeaderWarning.test.mjs
# TypeScript progress test runs after dependency installation via npm test.
test "$(node -p "require('./app/package.json').version")" = '1.6.35'
