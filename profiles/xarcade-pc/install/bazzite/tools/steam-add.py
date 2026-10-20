#!/usr/bin/env python3
"""Add installed Steam games to ES-DE. --scan lists missing games; --add APPID stages
metadata/art/trailer; --refresh safely applies staged entries and reloads the menu.
Existing launchers and artwork are retained. Steam itself handles game updates.
"""
from pathlib import Path
import argparse,datetime,json,re,subprocess,shutil,time,urllib.request,xml.etree.ElementTree as ET,os,signal
H=Path.home(); ROOT=H/'Emulation/roms/steam'; MED=H/'Emulation/tools/downloaded_media/steam'; PENDING=H/'Emulation/tools/steam-add-pending.json'
def installed():
 libraries={H/'.local/share/Steam/steamapps'}
 vf=H/'.local/share/Steam/steamapps/libraryfolders.vdf'
 if vf.exists():
  libraries.update(Path(p.replace('\\\\','\\'))/'steamapps' for p in re.findall(r'"path"\s+"([^"]+)"',vf.read_text()))
 result={}
 for lib in libraries:
  for f in lib.glob('appmanifest_*.acf'):
   d=dict(re.findall(r'"([^"\n]+)"\s+"([^"\n]*)"',f.read_text()))
   if int(d.get('StateFlags','0'))&4:result[d['appid']]=d
 return result
def existing_ids():
 ids=set()
 for p in ROOT.glob('*.sh'):
  ids.update(re.findall(r'^ID=(\d+)',p.read_text(),re.M))
 return ids
def fetch(url,out):
 if out.exists():return
 stage=out.with_name(out.name+'.partial')
 try:
  with urllib.request.urlopen(url,timeout=45) as r:stage.write_bytes(r.read())
  stage.replace(out)
 finally:
  if stage.exists():stage.unlink()
def add(appid,with_trailer):
 games=installed()
 if appid not in games:raise ValueError('That Steam game is not fully installed')
 if appid in existing_ids(): print(f'Already in ES-DE: {games[appid]["name"]}');return
 with urllib.request.urlopen('https://store.steampowered.com/api/appdetails?appids='+appid+'&l=english',timeout=45) as r:reply=json.load(r)[appid]
 if not reply.get('success'):raise ValueError('Steam store metadata unavailable; no entry created')
 d=reply['data']
 if d.get('type')!='game':raise ValueError('Only games are added, not DLC or software')
 name=games[appid]['name']; stem=re.sub(r'[<>:"/\\|?*]',' -',name).strip().rstrip('.')
 if not stem:raise ValueError('Empty game name')
 launcher=ROOT/(stem+'.sh')
 if launcher.exists():raise ValueError('A launcher with this name exists; leaving it untouched')
 for folder in ['marquees','covers','fanart','screenshots','videos','backcovers']:(MED/folder).mkdir(parents=True,exist_ok=True)
 controls=H/'Emulation/tools/maintenance/Arcade-Quick-Controls.png'
 if controls.exists() and not (MED/'backcovers'/(stem+'.png')).exists():shutil.copy2(controls,MED/'backcovers'/(stem+'.png'))
 cache=H/'.local/share/Steam/appcache/librarycache'/appid
 for filename,folder,ext in [('logo.png','marquees','png'),('library_600x900.jpg','covers','jpg'),('library_hero.jpg','fanart','jpg'),('header.jpg','screenshots','jpg')]:
  dest=MED/folder/(stem+'.'+ext)
  if dest.exists():continue
  if (cache/filename).exists():shutil.copy2(cache/filename,dest)
  elif folder=='screenshots':fetch(d['header_image'],dest)
  else:
   try:fetch(f'https://cdn.akamai.steamstatic.com/steam/apps/{appid}/{filename}',dest)
   except Exception as e:print(f'{folder} unavailable: {e}')
 logo=MED/'marquees'/(stem+'.png')
 if logo.exists():
  from PIL import Image
  with Image.open(logo) as im:
   if 'A' not in im.getbands() or im.getchannel('A').getextrema()[0]==255:print('Logo is opaque; use a transparent replacement if desired')
 if with_trailer and not (MED/'videos'/(stem+'.mp4')).exists():
  movies=d.get('movies',[])
  movie=next((m for m in movies if 'launch' in m.get('name','').lower()),movies[0] if movies else {})
  url=movie.get('hls_h264') or movie.get('mp4',{}).get('max')
  if url:
   tmp=MED/'videos'/(stem+'.partial.mp4')
   try:
    subprocess.run(['ffmpeg','-v','error','-y','-i',url,'-map','0:v:0','-map','0:a:0?','-vf','scale=1280:-2,fps=30','-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-af','loudnorm=I=-20:TP=-2:LRA=9','-c:a','aac','-b:a','128k','-movflags','+faststart',str(tmp)],check=True)
    subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(tmp),'-f','null','-'],check=True)
    tmp.replace(MED/'videos'/(stem+'.mp4'))
   finally:
    if tmp.exists():tmp.unlink()
  else:print('No official trailer available')
 # Reuse the proven Steam launch/wait behavior without editing other games.
 template=(ROOT/'Street Fighter 6.sh').read_text()
 launcher.write_text(template.replace('1364780',appid));launcher.chmod(0o755)
 released=''
 try:released=datetime.datetime.strptime(d['release_date']['date'],'%b %d, %Y').strftime('%Y%m%dT000000')
 except (ValueError,KeyError):pass
 entry={'path':'./'+launcher.name,'name':name,'desc':d.get('short_description',''),'developer':', '.join(d.get('developers',[])),'publisher':', '.join(d.get('publishers',[])),'genre':', '.join(g['description'] for g in d.get('genres',[]))}
 if released:entry['releasedate']=released
 pending=json.loads(PENDING.read_text()) if PENDING.exists() else {}
 pending[appid]=entry;PENDING.write_text(json.dumps(pending,indent=2))
 print('Prepared:',name,'— run steam-add.py --refresh when finished playing')
def pids(name):
 return [int(x) for x in subprocess.run(['pgrep','-x',name],capture_output=True,text=True).stdout.split()]
def refresh():
 if not PENDING.exists():print('No pending additions');return
 active=subprocess.run(['pgrep','-af','[r]eaper SteamLaunch AppId='],capture_output=True,text=True).stdout
 other=[x for x in active.splitlines() if 'AppId=3536773192 ' not in x]
 if other or pids('VPinballX_BGFX'):raise RuntimeError('A game is running. Close it before refreshing ES-DE.')
 was_open=bool(pids('es-de'))
 for pid in pids('es-de'):os.kill(pid,signal.SIGTERM)
 for _ in range(100):
  if not pids('es-de') and subprocess.run(['pgrep','-f','[r]eaper SteamLaunch AppId=3536773192'],stdout=subprocess.DEVNULL).returncode:break
  time.sleep(.5)
 else:raise RuntimeError('ES-DE did not close; pending entries retained')
 p=H/'ES-DE/gamelists/steam/gamelist.xml';tree=ET.parse(p);root=tree.getroot()
 shutil.copy2(p,H/'.cache'/('steam-gamelist-before-add-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S')+'.xml'))
 for entry in json.loads(PENDING.read_text()).values():
  if any(g.findtext('path')==entry['path'] for g in root.findall('game')):continue
  g=ET.SubElement(root,'game')
  for k,v in entry.items():ET.SubElement(g,k).text=v
  collection=H/'ES-DE/collections/custom-Street Fighter.cfg'
  if collection.exists() and re.search(r'street\s*fighter',entry['name'],re.I):
   lines=collection.read_text().splitlines();game=str(ROOT/entry['path'].removeprefix('./'))
   if game not in lines:collection.write_text('\n'.join(lines+[game])+'\n')
 ET.indent(tree,space='\t');tmp=p.with_suffix('.pending.xml');tree.write(tmp,encoding='utf-8',xml_declaration=True);tmp.replace(p)
 PENDING.unlink()
 if was_open:subprocess.Popen(['steam','-ifrunning',f'steam://rungameid/{(3536773192<<32)|0x02000000}'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,start_new_session=True)
 print('ES-DE additions applied'+(' and menu restarted' if was_open else ''))
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--scan',action='store_true');p.add_argument('--add',nargs='+',metavar='APPID');p.add_argument('--refresh',action='store_true');p.add_argument('--no-trailer',action='store_true');a=p.parse_args()
 if not any([a.scan,a.add,a.refresh]):p.print_help();return
 if a.scan:
  ids=existing_ids()
  for appid,d in sorted(installed().items(),key=lambda v:v[1]['name'].lower()):
   if appid not in ids and not re.match(r'Proton\b|Steam Linux Runtime|Steamworks Common',d['name'],re.I):print(appid,d['name'])
 if a.add:
  for appid in a.add:
   if not appid.isdecimal():raise ValueError('Steam app IDs must be numbers')
   add(appid,not a.no_trailer)
 if a.refresh:refresh()
if __name__=='__main__':main()
