#!/usr/bin/env bash
set -euo pipefail
base64 -d ci-src/v1642/modifications.patch.gz.b64 > /tmp/v1642-modifications.patch.gz
echo 'fbbe8cffe5941570bc368738bc3ecc5918ebc5d04fc4f62169be8fc0dbe9b660  /tmp/v1642-modifications.patch.gz' | sha256sum -c -
base64 -d ci-src/v1642/newfiles.tar.gz.b64 > /tmp/v1642-newfiles.tar.gz
echo 'fe54f64d12a3c35238becfee70c803ded6a33221be0be8d8afa35f3c80930b03  /tmp/v1642-newfiles.tar.gz' | sha256sum -c -
gzip -dc /tmp/v1642-modifications.patch.gz > /tmp/v1642-modifications.patch
# The initial v1.6.42 unified diff was generated against a local prior
# source tree. Some full-line matches drift in hosted reconstruction.
# Apply only safe matching hunks and transplant the others by stable anchors.
python3 - <<'PY'
from pathlib import Path
patch=Path('/tmp/v1642-modifications.patch').read_text()
skip={'src/App.tsx','src/components/StationForecastPanel.tsx','src/components/OfficialStationMapFrame.tsx','native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java','tests/stationKeepAlive.test.mjs'}
sections=[];chunk=[];bad=False
for line in patch.splitlines(keepends=True):
    if line.startswith('--- a/'):
        if chunk and not bad: sections.append(''.join(chunk))
        chunk=[line]
        bad=line[6:].rstrip() in skip
    else: chunk.append(line)
if chunk and not bad:sections.append(''.join(chunk))
Path('/tmp/v1642-safe.patch').write_text(''.join(sections))
PY
patch --batch --fuzz=0 -p1 -d app < /tmp/v1642-safe.patch
tar -xzf /tmp/v1642-newfiles.tar.gz -C app
python3 - <<'PY'
from pathlib import Path
R=Path('app')
def upd(name,a,b):
    p=R/name;s=p.read_text()
    if s.count(a)!=1:raise AssertionError(f"{name} expected one stable anchor, found {s.count(a)}: {a[:100]}")
    p.write_text(s.replace(a,b,1))
# The import anchor is unique; other components remain untouched.
upd('src/App.tsx','import { DeveloperPanel } from "./components/DeveloperPanel";',
 'import { DeveloperPanel } from "./components/DeveloperPanel";\nimport {readStationMapMode,writeStationMapMode,type StationMapMode} from "./utils/stationMapMode";')
upd('src/App.tsx','const [developerOpen, setDeveloperOpen] = useState(false);',
 'const [developerOpen, setDeveloperOpen] = useState(false);\n  const [stationMapMode,setStationMapMode]=useState<StationMapMode>(readStationMapMode);\n  const chooseStationMapMode=useCallback((mode:StationMapMode)=>{setStationMapMode(mode);writeStationMapMode(mode);},[]);')
upd('src/App.tsx','onInfoMetaChange={setStationInfoMeta} />',
 'onInfoMetaChange={setStationInfoMeta} stationMapMode={appSettings.developerMode?stationMapMode:"official"} autoRegionSwitch={appSettings.autoRegionSwitch} />')
upd('src/App.tsx','<DeveloperPanel warningLevel={devWarningLevel}',
 '<DeveloperPanel stationMapMode={stationMapMode} onStationMapMode={chooseStationMapMode} warningLevel={devWarningLevel}')
upd('src/components/StationForecastPanel.tsx','import { OfficialStationMapFrame } from "./OfficialStationMapFrame";',
 'import { OfficialStationMapFrame } from "./OfficialStationMapFrame";\nimport { ContinuousStationMap } from "./ContinuousStationMap";\nimport type {StationMapMode} from "../utils/stationMapMode";')
upd('src/components/StationForecastPanel.tsx','interface Props { active?:boolean;',
 'interface Props { stationMapMode?:StationMapMode;autoRegionSwitch?:boolean;active?:boolean;')
p=R/'src/components/StationForecastPanel.tsx';s=p.read_text()
import re
pattern=r'(?m)^(export const StationForecastPanel: React\.FC<Props> = \(\{[^\n]*?)\s*\}\) => \{'
s,n=re.subn(pattern,lambda m:m.group(1).rstrip()+',stationMapMode="official",autoRegionSwitch=true }) => {',s,count=1)
if n!=1:raise AssertionError('StationForecastPanel signature missing')
# Earlier CI layout omitted the information callback in the station signature.
sig=s.split('export const StationForecastPanel: React.FC<Props> = ({',1)[1].split('}) =>',1)[0]
if 'onOpenInfo' not in sig:
    s=s.replace(',stationMapMode="official",autoRegionSwitch=true }) => {',',onOpenInfo,stationMapMode="official",autoRegionSwitch=true }) => {',1)
if 'onOpenInfo?:()=>void' not in s:
    s=s.replace('interface Props {','interface Props { onOpenInfo?:()=>void;',1)
p.write_text(s)
p=R/'src/components/StationForecastPanel.tsx'
s=p.read_text()
import re
needle=r'(?m)^(\s*)<OfficialStationMapFrame (.+?) />$'
match=re.search(needle,s)
if not match:raise AssertionError('OfficialStationMapFrame single-line marker absent')
space=match.group(1);old=match.group(0)
new=(space+"{stationMapMode==='continuous' ? (\n"
+space+"  <ContinuousStationMap active={active} stations={data?.stations||[]} data={data} timestamp={controlTimestamp} userLocation={userLocation} onRequestGps={onRequestGps} isLocating={isLocating} onOpenStations={()=>setDetailOpen(true)} onSelectStation={station=>choose(station)} onOpenInfo={onOpenInfo} />\n"
+space+") : (\n"+space+"  <OfficialStationMapFrame "+match.group(2)+" stationMapMode={stationMapMode as 'official'|'auto'} autoRegionSwitch={autoRegionSwitch} />\n"
+space+")}")
p.write_text(s.replace(old,new,1))
p=R/'src/components/OfficialStationMapFrame.tsx';s=p.read_text()
if 'import type {StationMapMode}' not in s:
    s="import type {StationMapMode} from '../utils/stationMapMode';\n"+s
if 'setMapExperience(args:' not in s:
    import re
    # Insert into the real InlinePlugin interface, regardless of prior formatting.
    pattern=r'(  setLocationMarker\([^\n]*\);)'
    s,n=re.subn(pattern,lambda m:m.group(1)+'\n  setMapExperience(args:{mode:"official"|"auto";autoSwitchEnabled:boolean}):Promise<void>;',s,count=1)
    if n==0:
        s,n=re.subn(r'(?m)^(\s*toggleStationControls\([^\n]*;)',lambda m:m.group(1)+'\n  setMapExperience(args:{mode:"official"|"auto";autoSwitchEnabled:boolean}):Promise<void>;',s,count=1)
    if n!=1:raise AssertionError('InlinePlugin insertion point absent')
if 'stationMapMode?:Exclude<StationMapMode' not in s:
    pattern=r'(interface Props\s*\{)'
    s,n=re.subn(pattern,lambda m:m.group(1)+'\n  stationMapMode?:Exclude<StationMapMode,"continuous">;\n  autoRegionSwitch?:boolean;',s,count=1)
    if n==0:
        # Earlier CI reconstructs with inline props instead of a Props interface.
        needle='isLocating?:boolean}'
        if needle not in s:raise AssertionError('Official inline props declaration missing')
        s=s.replace(needle,'isLocating?:boolean;stationMapMode?:Exclude<StationMapMode,"continuous">;autoRegionSwitch?:boolean}',1)
if 'stationMapMode="official",autoRegionSwitch=true' not in s:
    pattern=r'(export function OfficialStationMapFrame\(\{[^\n]*?)\s*\}:(\{[^\n]*?\}|Props)\) \{'
    s,n=re.subn(pattern,lambda m:m.group(1).rstrip()+',stationMapMode="official",autoRegionSwitch=true}:'+m.group(2)+') {',s,count=1)
    if n!=1:raise AssertionError('OfficialStationMapFrame function missing')
if 'inline.setMapExperience(' not in s:
    anchor='  // GPS is opt-in.'
    effect="""  useEffect(()=>{
    if(!Capacitor.isNativePlatform())return;
    void inline.setMapExperience({mode:stationMapMode,autoSwitchEnabled:autoRegionSwitch}).catch(()=>{});
  },[stationMapMode,autoRegionSwitch,active]);
"""
    if anchor in s:s=s.replace(anchor,effect+anchor,1)
    else:
        anchor='  const toggleGps='
        if anchor not in s:raise AssertionError('GPS effect insertion missing')
        s=s.replace(anchor,effect+anchor,1)
p.write_text(s)
p=R/'native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java';s=p.read_text()
if s.count('private boolean regionMode = false;')!=1:raise AssertionError('regionMode anchor')
s=s.replace('private boolean regionMode = false;','private boolean regionMode = false;\n    private String stationExperience="official";\n    private boolean autoSwitchEnabled=true;',1)
anchor='    /** Public in-frame navigation without losing the app or its forecast controls. */'
method="""    @PluginMethod public void setMapExperience(PluginCall call) {
        String mode=call.getString("mode","official");
        if(!"official".equals(mode)&&!"auto".equals(mode)){call.reject("Invalid map experience");return;}
        final boolean enabled=Boolean.TRUE.equals(call.getBoolean("autoSwitchEnabled",true));
        getActivity().runOnUiThread(()->{
            stationExperience=mode;autoSwitchEnabled=enabled;
            syncMapExperience();call.resolve();
        });
    }
    private void syncMapExperience() {
        if(original==null||!loadState.canFit())return;
        final String config="window.__vedurspaStationMode="+JSONObject.quote(stationExperience)+
            ";window.__vedurspaAutoSwitchEnabled="+(autoSwitchEnabled?"true":"false")+";\\n";
        original.evaluateJavascript(config+OfficialMapAutoRegions.JAVASCRIPT,result->{});
    }

"""
if s.count(anchor)!=1:raise AssertionError('native plugin anchor missing')
s=s.replace(anchor,method+anchor,1)
needle='                    syncLocationMarker();'
if s.count(needle)<1:raise AssertionError('native ready marker missing')
s=s.replace(needle,needle+'\n                    syncMapExperience();',1)
p.write_text(s)
p=R/'tests/stationKeepAlive.test.mjs'
s=p.read_text()
if 'setMapExperience:async()=>{}' not in s:
  needle='goHome:async()=>'
  if s.count(needle)!=1:raise AssertionError('mock goHome anchor')
  s=s.replace(needle,'setMapExperience:async()=>{},'+needle,1)
p.write_text(s)
print('v1642 stable-anchor amendments applied')
PY
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