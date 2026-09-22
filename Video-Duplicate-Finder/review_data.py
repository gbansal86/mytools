"""Report parsing, file-size display, and Windows Recycle Bin helpers."""
from __future__ import annotations
import csv,ctypes,hashlib,os,re
from datetime import datetime
from pathlib import Path

def stable_id(group:int,path:Path)->str:return hashlib.sha1(f'{group}|{path}'.encode('utf-8','replace')).hexdigest()[:20]
def parse_report(path:Path):
    groups={};items={};group=None;keeper=None
    for raw in path.read_text(encoding='utf-8',errors='replace').splitlines():
        m=re.match(r'^\s*GROUP\s+(\d+)\s+-',raw,re.I)
        if m:group=int(m.group(1));keeper=None;groups.setdefault(group,[]);continue
        if group is None:continue
        if raw.startswith('Suggested keeper:'):keeper=raw.split(':',1)[1].strip();continue
        m=re.match(r'^\[(KEEP|DUP\?)\]\s+(.*)$',raw.strip(),re.I)
        if not m:continue
        p=Path(m.group(2).strip());i=stable_id(group,p)
        item={'id':i,'group':group,'tag':m.group(1).upper(),'path':p,'keeper':keeper==str(p),'exists':p.exists()}
        items[i]=item;groups[group].append(item)
    return groups,items

def human_size(path:Path)->str:
    try:n=path.stat().st_size
    except OSError:return 'Missing'
    v=float(n)
    for u in ['B','KB','MB','GB','TB']:
        if v<1024 or u=='TB':return f'{v:.2f} {u}'
        v/=1024

def recycle(path:Path):
    if os.name!='nt':return False,'Recycle Bin processing is Windows-only.'
    class Op(ctypes.Structure):
        _fields_=[('hwnd',ctypes.c_void_p),('wFunc',ctypes.c_uint),('pFrom',ctypes.c_wchar_p),('pTo',ctypes.c_wchar_p),('fFlags',ctypes.c_ushort),('fAnyOperationsAborted',ctypes.c_bool),('hNameMappings',ctypes.c_void_p),('lpszProgressTitle',ctypes.c_wchar_p)]
    op=Op();op.wFunc=3;op.pFrom=str(path)+'\0\0';op.fFlags=0x0004|0x0010|0x0040|0x0400
    rc=ctypes.windll.shell32.SHFileOperationW(ctypes.byref(op))
    if rc==0 and not op.fAnyOperationsAborted:return True,'Moved to Recycle Bin.'
    return False,'Operation aborted.' if op.fAnyOperationsAborted else f'Windows error {rc}.'

def log_action(log:Path,item:dict,ok:bool,message:str)->None:
    new=not log.exists()
    with log.open('a',newline='',encoding='utf-8-sig') as f:
        w=csv.writer(f)
        if new:w.writerow(['timestamp','group','tag','path','success','message'])
        w.writerow([datetime.now().isoformat(timespec='seconds'),item['group'],item['tag'],str(item['path']),ok,message])
