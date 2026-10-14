#!/usr/bin/env bash
set -euo pipefail
base64 -d ci-src/v1636/badge.patch.br.b64 > /tmp/v1636.patch.br
echo '2cf26198147f463c2efdbf6c4d595e913060e7fcce8dc9566cad4e4a07aad9ea  /tmp/v1636.patch.br' | sha256sum -c -
node -e "require('node:fs').writeFileSync('/tmp/v1636.patch',require('node:zlib').brotliDecompressSync(require('node:fs').readFileSync('/tmp/v1636.patch.br')))"
patch --batch -p1 -d app < /tmp/v1636.patch
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
for name in ('package.json','package-lock.json'):
    p=root/name
    data=json.loads(p.read_text())
    assert data['version']=='1.6.35',(name,data['version'])
    data['version']='1.6.36'
    if name=='package-lock.json':data['packages']['']['version']='1.6.36'
    else:data['scripts']['test'] += ' && node --import tsx tests/v1636UpdateBadge.test.ts'
    p.write_text(json.dumps(data,indent=2,ensure_ascii=False)+'\n')
p=root/'ci/patch_android.py'
s=p.read_text()
assert "'versionCode 42'" in s and "'versionName \"1.6.35\"'" in s
s=s.replace("'versionCode 42'","'versionCode 43'").replace("'versionName \"1.6.35\"'","'versionName \"1.6.36\"'")
s=s.replace('|41|42)', '|41|42|43)').replace(r'1\.6\.35)',r'1\.6\.35|1\.6\.36)')
p.write_text(s)
for p in (root/'tests').glob('*'):
    if p.suffix not in ('.mjs','.ts','.tsx'):continue
    s=p.read_text().replace('1.6.35','1.6.36').replace('versionCode 42','versionCode 43')
    if p.name in ('v1628UpdateSmoke.test.mjs','v1630SimpleUpdate.test.mjs'):
        s=s.replace(r'1\.6\.35',r'1\.6\.36')
    p.write_text(s)
(root/'RELEASE_NOTES_1.6.36.md').write_text("""# Veðurspá 1.6.36 — Automatic update check and notification badges

- Check the public latest GitHub Release whenever the app launches.
- Show a pulsing exclamation mark in the top-right corner of Settings when a newer version exists.
- Show the same indicator on the Updates icon in Settings.
- No badge when the installed version is current or the check fails.
- Respect the device's reduced-motion preference.
- Keep the existing manual update check, APK download progress and Android install/retry flows.
- All maps, cloud forecasts, saved language/theme settings and guidebook remain unchanged.
""")
(root/'AI_HANDOFF.md').write_text("""# AI_HANDOFF — Veðurspá 1.6.36

Purpose/state: Iceland weather forecast app, Vite/React/Capacitor6 Android is.viktor.vedurspa versionCode43/versionName1.6.36, Go Windows portable launcher. Latest complete source ZIP is authoritative.
Architecture/entry: src/App.tsx checks latest public release on mount using src/utils/appUpdate.ts; src/utils/updateAvailability.ts version gate; src/components/CompactHeader.tsx and AppSettingsPanel.tsx render the reusable UpdateAvailableBadge.tsx. Native Android updater bridge in src/utils/androidUpdater.ts, provider clients in src/utils/vedurDirectClient.ts, app themes/i18n/guide independent. ci/patch_android.py sets version, .github/workflows/build-release.yml runs CI.
Contracts: preserve HTTP/provider APIs, native AndroidUpdateStatus events, saved settings/themes/languages, warning levels red/orange/yellow, update button install/permission/download progress, existing ZIP layouts. No migrations; no private device telemetry. Badge only when latest version is newer, no push notifications or background polling. New fetch errors ignored for badge, manual retry remains possible.
Dependencies: Node20, npm Vite React TS, Capacitor6 Android Java17 SDK/Gradle; Go1.22 Windows launcher. Build: npm install; npm run lint; npm test; npm run build; npx cap add android && npx cap sync android && python3 ci/patch_android.py; cd android && ./gradlew assembleDebug; apksigner/aapt verify cert and code43. CI cross-compiles Go and ZIP. Dev mode: Settings tap version seven times.
Changes/tests: 1.6.35 updater percent/MB bar plus warning weekday/icon preserved; 1.6.36 startup latest-release lookup, pulsing Settings/Updates exclamation badges, reduced motion, v1636UpdateBadge.test.ts plus full regressions. Known risks: offline/HTTP errors cannot show badges, user needs network; actual phone visual/installer QA pending. Rollback to v1.6.35 signed release (Android downgrade may require uninstall). Next: install 1.6.36, publish temporary future newer release in test environment or test version comparator with mocks, and confirm badges disappear when current.
""")
(root/'BUILD_INFO.md').write_text('# Veðurspá 1.6.36\nVersionCode43, versionName1.6.36; signed APK + Windows + full source via GitHub Actions.\n')
(root/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.36\nCI runs targeted launch-badge test after dependency install; TypeScript lint, full regressions, web build, signed Android APK, Windows Go launcher and source ZIP. See GitHub run for results.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1635HeaderWarning.test.mjs
test "$(node -p "require('./app/package.json').version")" = '1.6.36'
