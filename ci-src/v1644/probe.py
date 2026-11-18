from urllib.request import Request, urlopen
import re
bases=['https://www.vedur.is','https://eldri.vedur.is']
paths=['/vedur/spar/thattaspar','/vedur/spar/nordurljos/','/vedur/spar/stadaspar/','/wstations/wslinfo.js?v=538','/wmap/wmap_isl.gif']
for path in paths:
 for base in bases:
  url=base+path
  try:
   with urlopen(Request(url,headers={'User-Agent':'Vedurspa/1.6.44 provider compatibility probe'}),timeout=12) as r:
    content=r.read(350000).decode('utf-8','ignore')
    print('PROBE',url,'status',r.status,'final',r.url,'content',r.headers.get('Content-Type',''),'bytes-preview',len(content),'imgConf',bool(re.search(r'imgConf\s*\[',content)),'wInfo',bool(re.search(r'wInfo\s*:',content)),'wTime',bool(re.search(r'wTime\s*:',content)),'VI.wsInfo',bool(re.search(r'VI\.wsInfo\s*=',content)),'wmap',content[:10].encode('ascii','replace').hex())
  except Exception as e: print('PROBE_ERROR',url,str(e)[:150])
url='https://spakort.vedur.is/kort/spakort/'
try:
 with urlopen(Request(url,headers={'User-Agent':'Vedurspa/1.6.44 provider compatibility probe'}),timeout=12) as r:
  content=r.read(100000).decode('utf-8','ignore');print('PROBE',url,r.status,'valid index','uwc-ig' in content)
except Exception as e: print('PROBE_ERROR',url,str(e)[:150])

# Inspect sample first-party HTML asset references without downloading full pages.
for path in ['/vedur/spar/thattaspar','/vedur/spar/nordurljos/','/vedur/spar/stadaspar/']:
 url='https://eldri.vedur.is'+path
 try:
  with urlopen(Request(url,headers={'User-Agent':'Vedurspa provider compatibility test'}),timeout=12) as r:
   html=r.read(160000).decode('utf8','ignore')
   print('SAMPLES',path,'imgs',re.findall(r"/photos/[^\"' <]+",html)[:3],'scripts',re.findall(r"<script[^>]+src=[\"']([^\"']+)",html)[:9], 'styles',re.findall(r"<link[^>]+href=[\"']([^\"']+)",html)[:7]);
 except Exception as e:print('SAMPLES_ERROR',path,str(e)[:100])
