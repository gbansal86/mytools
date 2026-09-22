"""Core video probing and perceptual fingerprint helpers."""
from __future__ import annotations
import json, os, shutil, subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional

VIDEO_EXTENSIONS={'.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm','.m4v','.mpg','.mpeg','.ts','.mts','.m2ts','.3gp','.vob','.ogv'}
SAMPLE_POSITIONS=[.05,.10,.20,.30,.40,.50,.60,.70,.80,.90,.95]
MIN_DURATION_SECONDS=20.0
FFMPEG_EXE='ffmpeg'; FFPROBE_EXE='ffprobe'

@dataclass
class VideoInfo:
    path:str; size:int; mtime_ns:int; duration:float; width:int; height:int; fingerprint:list[str]

def tool_path(name:str)->Optional[str]:
    system=shutil.which(name)
    if system: return system
    root=Path(__file__).resolve().parent/'_runtime'/'ffmpeg'
    exe=name if name.lower().endswith('.exe') else name+'.exe'
    if root.exists():
        for p in root.rglob(exe):
            if p.is_file(): return str(p.resolve())
    return None

def ensure_tools()->None:
    global FFMPEG_EXE,FFPROBE_EXE
    f,p=tool_path('ffmpeg'),tool_path('ffprobe')
    if not f or not p:
        print('\nERROR: ffmpeg/ffprobe missing. Run INSTALL_FIRST.bat first.')
        raise SystemExit(2)
    FFMPEG_EXE,FFPROBE_EXE=f,p
    print('Using FFmpeg :',f); print('Using FFprobe:',p)

def run_cmd(args:list[str],timeout:int=60)->subprocess.CompletedProcess:
    flags=getattr(subprocess,'CREATE_NO_WINDOW',0) if os.name=='nt' else 0
    return subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=flags,timeout=timeout,check=False)

def probe_video(path:Path)->Optional[tuple[float,int,int]]:
    args=[FFPROBE_EXE,'-v','error','-select_streams','v:0','-show_entries','format=duration:stream=width,height','-of','json',str(path)]
    try:
        cp=run_cmd(args,30)
        if cp.returncode: return None
        d=json.loads(cp.stdout.decode('utf-8','replace')); dur=float(d.get('format',{}).get('duration') or 0)
        s=d.get('streams',[]); w=int(s[0].get('width') or 0) if s else 0; h=int(s[0].get('height') or 0) if s else 0
        return (dur,w,h) if dur>0 else None
    except Exception: return None

def dhash(gray:bytes,w:int=9,h:int=8)->Optional[str]:
    if len(gray)<w*h:return None
    bits=idx=0
    for y in range(h):
        row=y*w
        for x in range(w-1):
            if gray[row+x]>gray[row+x+1]:bits|=1<<idx
            idx+=1
    return f'{bits:016x}'

def frame_hash_at(path:Path,t:float)->Optional[str]:
    args=[FFMPEG_EXE,'-v','error','-ss',f'{max(0,t):.3f}','-i',str(path),'-frames:v','1','-vf','scale=9:8:flags=area,format=gray','-f','rawvideo','-pix_fmt','gray','pipe:1']
    try:
        cp=run_cmd(args,30); return dhash(cp.stdout) if cp.returncode==0 else None
    except Exception:return None

def make_fingerprint(path:Path,duration:float)->list[str]:
    return [frame_hash_at(path,duration*p) or '' for p in SAMPLE_POSITIONS]

def load_cache(path:Path)->dict:
    try:return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
    except Exception:return {}

def save_cache(path:Path,cache:dict)->None:
    tmp=path.with_suffix('.tmp'); tmp.write_text(json.dumps(cache,indent=2),encoding='utf-8'); tmp.replace(path)

def get_video_info(path:Path,cache:dict)->Optional[VideoInfo]:
    try: st=path.stat(); key=str(path.resolve())
    except OSError:return None
    c=cache.get(key)
    if isinstance(c,dict) and c.get('size')==st.st_size and c.get('mtime_ns')==st.st_mtime_ns and c.get('fingerprint'):
        try:return VideoInfo(**c)
        except TypeError:pass
    probed=probe_video(path)
    if not probed: print('  SKIP unreadable:',path); return None
    dur,w,h=probed
    if dur<MIN_DURATION_SECONDS: print(f'  SKIP short ({dur:.1f}s):',path); return None
    print(f'  Fingerprinting: {path.name} ({dur/60:.1f} min)')
    fp=make_fingerprint(path,dur)
    if sum(bool(x) for x in fp)<5: print('  SKIP insufficient frames:',path); return None
    info=VideoInfo(key,st.st_size,st.st_mtime_ns,dur,w,h,fp); cache[key]=asdict(info); return info
