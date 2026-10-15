#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import json
root=Path('app')
p=root/'src/components/StationForecastPanel.tsx';s=p.read_text()
needle='  const [detailOpen,setDetailOpen]=useState(false);'
assert needle in s
s=s.replace(needle,needle+'\n  const [sourceDetailsOpen,setSourceDetailsOpen]=useState(false);')
a='''      <div className="relative flex-1 min-h-0"><OfficialStationMapFrame refreshToken={refreshToken} active={active} timestamp={controlTimestamp} suspended={suspendOfficialMap || locationChooser || detailOpen} onOpenStations={()=>setDetailOpen(true)} />
      <SourceAttribution url="https://www.vedur.is/vedur/spar/stadaspar/" sourceFetchedAt={data?.fetchedAt} validAt={controlTimestamp} kind="station" compact />
      </div>
      <WeatherMapTimeline times={controlTimes} active={active} index={controlIndex} onChange={changeControlTime} onJumpToNow={jumpToNow} label="Tími staðaspákorts"/>'''
b='''      {/* The native map must remain a direct flex child. The added attribution
          wrapper in 1.6.37 collapsed its WebView height to zero. */}
      <OfficialStationMapFrame refreshToken={refreshToken} active={active} timestamp={controlTimestamp} suspended={suspendOfficialMap || locationChooser || detailOpen || sourceDetailsOpen} onOpenStations={()=>setDetailOpen(true)} />
      <WeatherMapTimeline times={controlTimes} active={active} index={controlIndex} onChange={changeControlTime} onJumpToNow={jumpToNow} label="Tími staðaspákorts"
        attribution={<SourceAttribution url="https://www.vedur.is/vedur/spar/stadaspar/" sourceFetchedAt={data?.fetchedAt} validAt={controlTimestamp} kind="station" compact inline onDetailsChange={setSourceDetailsOpen} />}/>
'''
assert a in s
p.write_text(s.replace(a,b))
p=root/'src/components/SourceAttribution.tsx';s=p.read_text()
repls=[
("kind?:'weather'|'aurora'|'station'|'four';compact?:boolean;","kind?:'weather'|'aurora'|'station'|'four';compact?:boolean;inline?:boolean;onDetailsChange?:(open:boolean)=>void;"),
("kind='weather',compact=false})=>{","kind='weather',compact=false,inline=false,onDetailsChange})=>{"),
("const open=()=>{opener.current=document.activeElement as HTMLElement;setDetails(true);};","const open=()=>{opener.current=document.activeElement as HTMLElement;setDetails(true);onDetailsChange?.(true);};"),
("const close=()=>{setDetails(false);opener.current?.focus();};","const close=()=>{setDetails(false);onDetailsChange?.(false);opener.current?.focus();};"),
("absolute \x24{compact?'bottom-1 right-1':'bottom-2 right-2'} z-30", "\x24{inline?'relative shrink-0 h-5 py-0':'absolute '+(compact?'bottom-1 right-1':'bottom-2 right-2')} z-30"),
("bg-slate-950/90 px-2 py-1.5 text-[10px]","bg-slate-950/90 px-2 \x24{inline?'':'py-1.5'} text-[10px]")]
for a,b in repls:
    assert a in s, a
    s=s.replace(a,b)
p.write_text(s)
p=root/'src/components/WeatherMapTimeline.tsx';s=p.read_text()
a="  accent?: 'cyan' | 'yellow';"
assert a in s
s=s.replace(a,a+"\n  attribution?: React.ReactNode;")
a="label, active=true, onJumpToNow }) => {"
assert a in s
s=s.replace(a,"label, active=true, onJumpToNow, attribution }) => {")
a='''<div className="min-h-5 px-2 pb-0.5 text-xs leading-5 text-slate-300 font-bold text-center tabular-nums" aria-live="polite">{new Date(times[safe]).toLocaleString('is-IS',{timeZone:'Atlantic/Reykjavik',weekday:'short',day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}</div>'''
b='''<div className="relative min-h-5 px-2 pb-0.5 flex items-center justify-center text-xs leading-5 text-slate-300 font-bold text-center tabular-nums" aria-live="polite">
      <span>{new Date(times[safe]).toLocaleString('is-IS',{timeZone:'Atlantic/Reykjavik',weekday:'short',day:'numeric',month:'short',hour:'2-digit',minute:'2-digit'})}</span>
      {attribution && <span className="absolute right-1 top-0 bottom-0 flex items-center">{attribution}</span>}
    </div>'''
assert a in s
p.write_text(s.replace(a,b))
p=root/'tests/v1638StationMapRegression.test.mjs'
p.write_text('''import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const read=p=>readFileSync(new URL('../'+p,import.meta.url),'utf8');
const station=read('src/components/StationForecastPanel.tsx'),source=read('src/components/SourceAttribution.tsx'),timeline=read('src/components/WeatherMapTimeline.tsx');
assert.match(station,/<OfficialStationMapFrame refreshToken=/);
assert.doesNotMatch(station,/<div className="relative flex-1 min-h-0"><OfficialStationMapFrame/);
assert.match(station,/sourceDetailsOpen/);
assert.match(station,/attribution=\\{<SourceAttribution/);
assert.match(timeline,/attribution\\?: React.ReactNode/);
assert.match(timeline,/relative min-h-5/);
assert.match(source,/onDetailsChange\\?\\.\\(true\\)/);
assert.match(source,/onDetailsChange\\?\\.\\(false\\)/);
assert.match(source,/inline\\?'relative shrink-0 h-5 py-0'/);
console.log('Veðurspá 1.6.38 native Staðaspá layout fix and attribution PASS');
''')
for name in ('package.json','package-lock.json'):
    p=root/name;d=json.loads(p.read_text());assert d['version']=='1.6.37';d['version']='1.6.38'
    if name=='package-lock.json':d['packages']['']['version']='1.6.38'
    else:d['scripts']['test']+=' && node tests/v1638StationMapRegression.test.mjs'
    p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=root/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 44'" in s and "'versionName \"1.6.37\"'" in s
s=s.replace("'versionCode 44'","'versionCode 45'").replace("'versionName \"1.6.37\"'","'versionName \"1.6.38\"'")
s=s.replace('|43|44)', '|43|44|45)').replace(r'1\.6\.37)',r'1\.6\.37|1\.6\.38)')
p.write_text(s)
for p in (root/'tests').glob('*'):
    if p.name=='v1638StationMapRegression.test.mjs' or p.suffix not in ('.mjs','.ts','.tsx'):continue
    s=p.read_text().replace('1.6.37','1.6.38').replace('versionCode 44','versionCode 45')
    if p.name in ('v1628UpdateSmoke.test.mjs','v1630SimpleUpdate.test.mjs'):s=s.replace(r'1\.6\.37',r'1\.6\.38')
    if p.name=='v1636UpdateBadge.test.ts':
        s=s.replace("isNewerRelease({version:'1.6.38'},'1.6.38'), true", "isNewerRelease({version:'1.6.39'},'1.6.38'), true")
    p.write_text(s)
(root/'RELEASE_NOTES_1.6.38.md').write_text('# Veðurspá 1.6.38 — Staðaspá map restoration\n\n- Restore blank Staðaspá native WebView by removing a non-flex frame wrapper introduced by 1.6.37.\n- Keep map full height; move source attribution to the pre-existing date/time row, outside the Android native WebView.\n- Suspend the native map when attribution dialog opens; restore it on close.\n- Preserve legal/source metadata, maps, themes, guides and updater.\n')
(root/'AI_HANDOFF.md').write_text('''# AI_HANDOFF — Veðurspá 1.6.38
Android package is.viktor.vedurspa versionCode45/versionName1.6.38. React/Vite frontend + Capacitor6 native map plugin; Go Windows localhost launcher.
CRITICAL BUG: Staðaspá showed a blank black viewport in v1.6.37. The legal attribution change wrapped OfficialStationMapFrame in a non-flex div; native WebView placeholder height collapsed to 0. Fix: restore OfficialStationMapFrame as DIRECT child of .station-map-main flex column. Move SourceAttribution into the existing time/date bar via WeatherMapTimeline attribution prop. The native WebView draws over HTML overlays, so attribution outside the map is more reliable. Source modal state suspends WebView, restores on close.
Preserve map full height, existing time bar height 20px, official station controls, regions, zoom, timestamp, site caching, per-image legal provenance, privacy, warnings, nine languages, themes, guidebook and updater.
Tests: tests/v1638StationMapRegression.test.mjs plus all prior. CI rebuilds APK, PC ZIP, complete source. Build Node20 npm install, npm run lint, npm test, npm run build, npx cap add android, npx cap sync android, python3 ci/patch_android.py, cd android && ./gradlew assembleDebug, verify versionCode45 and signature. Windows Go1.22 crossbuild. Developer mode: tap version 7 times. Phone validation of native WebView still required.
''')
(root/'BUILD_INFO.md').write_text('# Veðurspá 1.6.38\nAndroid versionCode 45; CI builds signed APK, Windows portable launcher and source ZIP.\n')
(root/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.38\nCI runs full regression and Staðaspá layout contract, web build, Android signing/version and Windows packaging. Physical Android map check still required.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1638StationMapRegression.test.mjs
test "$(node -p "require('./app/package.json').version")" = "1.6.38"
