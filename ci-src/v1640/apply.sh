#!/usr/bin/env bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
import json
R=Path('app')
def edit(path,old,new):
 p=R/path;s=p.read_text()
 if old not in s:raise RuntimeError(f'1.6.39 source drift: {path}: {old[:85]}')
 p.write_text(s.replace(old,new,1))
gps_js="""(function(){
 try{
 const c=document.getElementById('wmap1'),p=window.__vedurspaGpsPoint;
 document.getElementById('vedurspa-gps-marker')?.remove();
 if(!p?.enabled||!c)return {visible:false,reason:'off'};
 const lat=Number(p.lat),lon=Number(p.lon);
 if(!Number.isFinite(lat)||!Number.isFinite(lon)||lat<62||lat>68||lon< -26||lon> -11)return {visible:false,reason:'outside-iceland'};
 const img=c.querySelector('img[src*="wmap_"]');if(!img)return {visible:false,reason:'map-image-missing'};
 const url=new URL(img.getAttribute('src')||'',location.href);
 const national=/\\/wmap\\/wmap_isl\\.gif$/i.test(url.pathname);
 const width=img.naturalWidth||img.width||c.offsetWidth,height=img.naturalHeight||img.height||c.offsetHeight;
 if(!(width>50&&height>40))return {visible:false,reason:'unmeasured-image'};
 const sources=[window.VI?.conf?.mCtrl?.wmapCtrl?.conf,window.VI?.conf?.mCtrl?.wmapCtrl,window.VI?.conf?.mCtrl?.conf,window.VI?.conf?.mCtrl,window.VI?.conf,window.wmapCtrl?.conf];
 let v=sources.find(o=>o&&['wmapLLLat','wmapLLLon','wmapTRLat','wmapTRLon','wmapMapLon'].every(k=>Number.isFinite(Number(o[k]))));
 if(!v&&national)v={wmapLLLat:63.19,wmapLLLon:-24.15,wmapTRLat:66.59,wmapTRLon:-12.95,wmapMapLon:-19,wmapWidth:540,wmapHeight:390};
 if(!v)return {visible:false,reason:'regional-calibration-unavailable'};
 const llLat=Number(v.wmapLLLat),llLon=Number(v.wmapLLLon),trLat=Number(v.wmapTRLat),trLon=Number(v.wmapTRLon),mid=Number(v.wmapMapLon);
 if(!(trLat>llLat&&trLon>llLon))return {visible:false,reason:'invalid-calibration'};
 const dr=Math.PI/180,project=(a,b)=>{let t=Math.sin((45-a/2)*dr)/Math.cos((45-a/2)*dr);return {x:2*t*Math.sin((-b+mid)*dr),y:-2*t*Math.cos((-b+mid)*dr)};};
 const ll=project(llLat,llLon),tr=project(trLat,trLon),pt=project(lat,lon),dx=tr.x-ll.x;
 if(Math.abs(dx)<1e-9)return {visible:false,reason:'degenerate'};
 const w=Number(v.wmapWidth)||width,h=Number(v.wmapHeight)||height;
 let x=1+(w-1)*(pt.x-ll.x)/dx,y=h-(1+(w-1)*(ll.y-pt.y)/dx);
 if(national&&Math.abs(w-540)<2&&Math.abs(h-390)<2){x=x*1.00458-4.19;y=y*1.00403+6.79;}
 x*=width/w;y*=height/h;
 if(!(x>=0&&x<=width&&y>=0&&y<=height))return {visible:false,reason:'outside-this-map'};
 if(getComputedStyle(c).position==='static')c.style.position='relative';
 const m=document.createElement('div');m.id='vedurspa-gps-marker';m.setAttribute('aria-label','Mín staðsetning (GPS)');
 m.style.cssText='position:absolute;left:'+x+'px;top:'+y+'px;width:20px;height:20px;transform:translate(-50%,-50%);border-radius:50%;border:3px solid white;background:#0369a1;box-shadow:0 0 0 4px #07598555,0 2px 6px #0009;z-index:2147483400;pointer-events:none;box-sizing:border-box;';
 c.appendChild(m);return {visible:true,x,y};
 }catch(e){return {visible:false,reason:'render-error'};}
})();"""
# JS is kept readable, reviewed and regenerated to Java at build time.
(R/'ci/official_widget_gps.js').write_text(gps_js+'\n')
java=('package is.viktor.vedurspa;\n'
      '/** Generated from ci/official_widget_gps.js. */\n'
      'public final class OfficialMapGps {private OfficialMapGps(){}\n'
      'public static final String JAVASCRIPT =\n'+
      ' +\n'.join('    '+json.dumps(line+'\n') for line in gps_js.splitlines())+';\n}\n')
(R/'native-src/is/viktor/vedurspa/OfficialMapGps.java').write_text(java)
p=R/'native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java'
s=p.read_text()
s=s.replace('private boolean regionMode = false;','private boolean regionMode = false;\n    private boolean gpsEnabled=false; private double gpsLat=0d,gpsLon=0d;')
anchor='    /** Public in-frame navigation without losing the app or its forecast controls. */'
native="""    /** Coordinates remain on-device and only display after explicit user action. */
    @PluginMethod public void setLocationMarker(PluginCall call) {
        boolean enabled=Boolean.TRUE.equals(call.getBoolean("enabled",false));
        Double lat=call.getDouble("lat",0d),lon=call.getDouble("lon",0d);
        if(enabled&&(lat==null||lon==null||!Double.isFinite(lat)||!Double.isFinite(lon)||
          lat<62||lat>68||lon< -26||lon> -11)){call.reject("Invalid Iceland GPS location");return;}
        getActivity().runOnUiThread(()->{
            gpsEnabled=enabled;if(enabled){gpsLat=lat;gpsLon=lon;}
            syncLocationMarker();
            JSObject out=new JSObject();out.put("enabled",enabled);call.resolve(out);
        });
    }
    private void syncLocationMarker() {
        if(original==null||!loadState.canFit())return;
        String js="window.__vedurspaGpsPoint={enabled:"+(gpsEnabled?"true":"false")+
          ",lat:"+Double.toString(gpsLat)+",lon:"+Double.toString(gpsLon)+"};\\n"+
          OfficialMapGps.JAVASCRIPT;
        original.evaluateJavascript(js,result->{
            try{
                JSONObject v=new JSONObject(result),out=v;
                JSObject status=new JSObject();
                status.put("visible",out.optBoolean("visible",false));
                status.put("reason",out.optString("reason",""));
                notifyListeners("gpsStatus",status);
            }catch(Exception ignored){}
        });
    }
"""
assert anchor in s
s=s.replace(anchor,native+'\n'+anchor)
assert 'if(regionMode) applyRegionMode();' in s
s=s.replace('if(regionMode) applyRegionMode();','if(regionMode) applyRegionMode();\n                    syncLocationMarker();',1)
p.write_text(s)
p=R/'ci/official_widget_focus.js';s=p.read_text().replace(':not(#vedurspa-region-overlay){',':not(#vedurspa-region-overlay):not(#vedurspa-gps-marker){');p.write_text(s)
# Source-generated focus Java is authoritative after source CSS changes.
import subprocess
subprocess.run(['python3',str(R/'ci/generate_official_map_focus.py')],check=True)
edit('src/components/CompactHeader.tsx','Settings, CircleHelp, Info','Settings, Info')
edit('src/components/CompactHeader.tsx','  onOpenGuide: () => void;\n','')
edit('src/components/CompactHeader.tsx','onOpenSettings, onOpenInfo, onOpenGuide, updateAvailable','onOpenSettings, onOpenInfo, updateAvailable')
p=R/'src/components/CompactHeader.tsx';s=p.read_text()
s='\n'.join(line for line in s.split('\n') if 'id="btn-app-guide"' not in line);p.write_text(s)
edit('src/App.tsx','GuidedTour, hasCompletedGuide, markGuideComplete, type GuideKind','GuidedTour, markGuideComplete, type GuideKind')
p=R/'src/App.tsx';s=p.read_text()
s='\n'.join(line for line in s.split('\n') if 'if(hasCompletedGuide())return' not in line and 'onOpenGuide={()' not in line)
p.write_text(s)
edit('src/components/OfficialStationMapFrame.tsx',"import { ArrowLeft } from 'lucide-react';","import { ArrowLeft, LocateFixed } from 'lucide-react';\nimport type { UserLocation } from '../types';")
edit('src/components/OfficialStationMapFrame.tsx','  toggleStationControls():Promise<void>;','  toggleStationControls():Promise<void>;\n  setLocationMarker(args:{enabled:boolean;lat?:number;lon?:number}):Promise<{enabled:boolean}>;')
edit('src/components/OfficialStationMapFrame.tsx',
 'export function OfficialStationMapFrame({timestamp, refreshToken=0,active=true,suspended=false,onOpenStations}:{refreshToken?:number;active?:boolean;onOpenStations?:()=>void;timestamp?:string; suspended?:boolean}) {',
 'export function OfficialStationMapFrame({timestamp, refreshToken=0,active=true,suspended=false,onOpenStations,userLocation,onRequestGps,isLocating=false}:{refreshToken?:number;active?:boolean;onOpenStations?:()=>void;timestamp?:string;suspended?:boolean;userLocation?:UserLocation|null;onRequestGps?:()=>void;isLocating?:boolean}) {')
edit('src/components/OfficialStationMapFrame.tsx','  const [regionMode,setRegionMode]=useState(false);','  const [regionMode,setRegionMode]=useState(false);\n  const [gpsEnabled,setGpsEnabled]=useState(false);')
anchor='  // Our normal Staðaspá timeline drives the original widget (not a decorative duplicate).'
effect="""  // Position is projected inside the native WebView's original map image. Never
  // mistake a saved preset for a current GPS fix.
  useEffect(()=>{
    if(!Capacitor.isNativePlatform())return;
    const enabled=active&&gpsEnabled&&!!userLocation?.isGps;
    void inline.setLocationMarker(enabled?
      {enabled:true,lat:userLocation!.lat,lon:userLocation!.lon}:{enabled:false}).catch(()=>{});
  },[active,gpsEnabled,userLocation?.isGps,userLocation?.lat,userLocation?.lon]);
  const toggleGps=()=>{
    if(gpsEnabled){setGpsEnabled(false);return;}
    setGpsEnabled(true);
    if(!userLocation?.isGps)onRequestGps?.();
  };
"""
edit('src/components/OfficialStationMapFrame.tsx',anchor,effect+anchor)
anchor='    {onOpenStations && <button type="button" onClick={onOpenStations} className="flex-1 min-h-10 px-2 rounded-lg border border-slate-600 text-sm font-semibold whitespace-nowrap">Stöðvar ▾</button>}'
button="""    {onOpenStations && <button type="button" onClick={onOpenStations} className="min-w-0 min-h-10 px-1 rounded-lg border border-slate-600 text-sm font-semibold whitespace-nowrap">Stöðvar ▾</button>}
    <button id="station-gps-button" type="button" onClick={toggleGps}
      disabled={!Capacitor.isNativePlatform()||isLocating} aria-pressed={gpsEnabled}
      aria-label={gpsEnabled?'Fela GPS staðsetningu':'Sýna mína staðsetningu á korti'}
      className={`w-11 h-11 shrink-0 rounded-lg border flex items-center justify-center disabled:opacity-50 ${gpsEnabled?'bg-cyan-800 border-cyan-300 text-white':'bg-slate-800 border-slate-600 text-white'}`}>
      <LocateFixed className="w-5 h-5"/>
    </button>"""
edit('src/components/OfficialStationMapFrame.tsx',anchor,button)
edit('src/components/StationForecastPanel.tsx','onOpenStations={()=>setDetailOpen(true)} />','onOpenStations={()=>setDetailOpen(true)} userLocation={userLocation} onRequestGps={onRequestGps} isLocating={isLocating} />')
edit('src/index.css','.station-map-nav {padding:0;gap:3px;display:grid;grid-template-columns:repeat(3,minmax(0,1fr));}', '.station-map-nav {padding:0;gap:3px;display:grid;grid-template-columns:repeat(3,minmax(0,1fr)) 44px;}')
# Target the recent exact-version assertions; leave historical v1.6.39 comparison cases in place.
for filename in ('v1635HeaderWarning.test.mjs','v1639InfoHub.test.mjs'):
 p=R/'tests'/filename;s=p.read_text().replace('1.6.39','1.6.40').replace(r'1\.6\.39',r'1\.6\.40');p.write_text(s)
p=R/'tests/v1631LanguageGuide.test.mjs';s=p.read_text().replace('assert.match(app,/hasCompletedGuide/);','assert.doesNotMatch(app,/hasCompletedGuide\\(\\)/);').replace('assert.match(header,/btn-app-guide/);','assert.doesNotMatch(header,/btn-app-guide/);');p.write_text(s)
# Update the native-map lifecycle test double for the new opt-in bridge method.
p=R/'tests/stationKeepAlive.test.mjs';st=p.read_text()
needle="goHome:async()=>{calls.push(['goHome']);},addListener:"
assert needle in st
st=st.replace(needle,"goHome:async()=>{calls.push(['goHome']);},setLocationMarker:async()=>({enabled:false}),addListener:")
st=st.replace("'lucide-react':{ArrowLeft:()=>null}","'lucide-react':{ArrowLeft:()=>null,LocateFixed:()=>null}")
p.write_text(st)
p=R/'tests/v1640GpsGuide.test.mjs'
p.write_text("""import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const r=f=>readFileSync(new URL('../'+f,import.meta.url),'utf8');
const app=r('src/App.tsx'),header=r('src/components/CompactHeader.tsx'),frame=r('src/components/OfficialStationMapFrame.tsx');
assert.match(frame,/station-gps-button/);
assert.match(frame,/userLocation\\?\\.isGps/);
assert.match(frame,/inline\\.setLocationMarker/);
assert.match(r('native-src/is/viktor/vedurspa/OfficialInlineMapPlugin.java'),/setLocationMarker/);
assert.match(r('ci/official_widget_gps.js'),/regional-calibration-unavailable/);
assert.doesNotMatch(header,/btn-app-guide|CircleHelp/);
assert.doesNotMatch(app,/hasCompletedGuide\\(\\)/);
assert.match(r('src/components/AppSettingsPanel.tsx'),/settings-panel-guide/);
console.log('1.6.40 station GPS / settings-only guide PASS');
""")
for name in ('package.json','package-lock.json'):
 p=R/name;d=json.loads(p.read_text());assert d['version']=='1.6.39';d['version']='1.6.40'
 if name=='package-lock.json':d['packages']['']['version']='1.6.40'
 else:d['scripts']['test']+=' && node tests/v1640GpsGuide.test.mjs'
 p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
p=R/'ci/patch_android.py';s=p.read_text()
assert "'versionCode 46'" in s and "'versionName \"1.6.39\"'" in s
s=s.replace("'versionCode 46'","'versionCode 47'").replace("'versionName \"1.6.39\"'","'versionName \"1.6.40\"'")
s=s.replace('|45|46)', '|45|46|47)').replace(r'1\.6\.39)',r'1\.6\.39|1\.6\.40)')
p.write_text(s)
(R/'RELEASE_NOTES_1.6.40.md').write_text("""# Veðurspá 1.6.40 — Staðaspá GPS marker and guide cleanup

- New opt-in GPS button immediately beside Stöðvar.
- Location marker drawn INSIDE the original native Staðaspá map, with per-map geographic calibration and zoom/pan inheritance.
- If geographic calibration for a regional map is missing, no misleading location is shown.
- Removed main-header Help button and automatic first-run walkthrough. Guides remain under Settings.
- Preserves map size, weather products, legal attribution, themes, update progress and Android signing.
""")
(R/'AI_HANDOFF.md').write_text("""# Veðurspá 1.6.40 — AI handoff

Android package is.viktor.vedurspa, versionName 1.6.40 versionCode 47. React/Vite/Capacitor6 Android + Go Windows launcher.
Staðaspá: Original WebView inside OfficialInlineMapPlugin retains direct flex sizing. New setLocationMarker native method uses ci/official_widget_gps.js/OfficialMapGps.java to project GPS into the SOURCE IMAGE coordinates of the current provider page. It follows the provider's widget pinch-zoom/pan and uses the published VI.conf regional bounds. If regional calibration is unavailable, the marker is omitted; never fake geographic positions. Button is beside Stöðvar in OfficialStationMapFrame; opt-in location permission via App.handleRequestGps, never persist GPS coordinates.
Guide: main header Help icon and unsolicited first-run guided tour removed. Settings Guide tab and GuideBook unchanged. Legal/source disclosure still in header, attribution details remain.
Source of truth: this complete source ZIP. Keep generated native Java in sync with ci/official_widget_gps.js; Focus JS generated by ci/generate_official_map_focus.py. CI builds signed Android APK, Windows portable ZIP and full source; developer mode by 7 taps version in Settings. Validate real Android native map and regional page georeferencing on device.
""")
(R/'BUILD_INFO.md').write_text('# Veðurspá 1.6.40\nAndroid versionCode 47, appId is.viktor.vedurspa. Release via GitHub Actions.\n')
(R/'TEST_RESULTS.md').write_text('# Veðurspá 1.6.40\nGitHub Actions checks TypeScript, regressions, web, Android signing/manifest, Windows packaging. Physical Android GPS/map verification pending.\n')
PY
python3 -m py_compile app/ci/patch_android.py
node app/tests/v1640GpsGuide.test.mjs
node --check app/ci/official_widget_gps.js
test "$(node -p "require('./app/package.json').version")" = 1.6.40
