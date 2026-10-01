#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, os, platform, shutil, sys, tempfile, time, zipfile
from datetime import datetime
from pathlib import Path, PurePosixPath

PROTECTED_DIRS = {'data','runtime','logs','updates','support_packages'}
PROTECTED_FILES = {'config/urls.txt'}
SKIP_NAMES = {'.pytest_cache','__pycache__'}
SKIP_SUFFIXES = {'.pyc','.pyo'}


def _stamp(): return datetime.now().strftime('%Y%m%d_%H%M%S')
def _sha(path: Path) -> str:
    h=hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda:f.read(1024*1024),b''): h.update(chunk)
    return h.hexdigest()

def _safe_member(name: str) -> PurePosixPath:
    p=PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts: raise ValueError(f'Unsafe ZIP path: {name}')
    return p

def _find_zip_root(z: zipfile.ZipFile) -> str:
    files=[str(_safe_member(n)).rstrip('/') for n in z.namelist() if n and not n.endswith('/')]
    candidates=[]
    for n in files:
        if n.endswith('/VERSION.txt') or n=='VERSION.txt':
            root=n[:-len('VERSION.txt')].rstrip('/')
            candidates.append(root)
    for root in candidates or ['']:
        prefix=(root+'/' if root else '')
        names=set(files)
        if prefix+'VERSION.txt' in names and any(n.startswith(prefix+'app/') for n in names): return root
    raise ValueError('ZIP is not a Downloadly Catalog Manager package (VERSION.txt/app missing).')

def _rel_from_root(name: str, root: str) -> Path | None:
    p=str(_safe_member(name)).rstrip('/')
    if not p: return None
    prefix=(root+'/' if root else '')
    if prefix and not p.startswith(prefix): return None
    rel=p[len(prefix):]
    if not rel: return None
    return Path(*PurePosixPath(rel).parts)

def _skip_rel(rel: Path) -> bool:
    parts=rel.parts
    return any(x in SKIP_NAMES for x in parts) or rel.suffix.lower() in SKIP_SUFFIXES

def _protected(rel: Path) -> bool:
    pos=rel.as_posix()
    return (bool(rel.parts) and rel.parts[0] in PROTECTED_DIRS) or pos in PROTECTED_FILES


def apply_update_zip(package_root: Path|str, zip_path: Path|str) -> dict:
    """Overlay changed/new program files from a package ZIP while preserving user data."""
    package_root=Path(package_root).resolve(); zip_path=Path(zip_path).resolve()
    if not zip_path.exists(): raise FileNotFoundError(zip_path)
    backup=package_root/'updates'/'backups'/f'backup_{_stamp()}'
    changed=added=unchanged=skipped=0; copied=[]
    with zipfile.ZipFile(zip_path) as z:
        root=_find_zip_root(z)
        members=[]
        for info in z.infolist():
            if info.is_dir(): continue
            rel=_rel_from_root(info.filename,root)
            if rel is None or _skip_rel(rel): continue
            if _protected(rel): skipped+=1; continue
            members.append((info,rel))
        # Extract one file at a time to avoid trusting archive paths.
        for info,rel in members:
            target=package_root/rel
            data=z.read(info)
            if target.exists():
                old_hash=hashlib.sha256(target.read_bytes()).digest(); new_hash=hashlib.sha256(data).digest()
                if old_hash==new_hash: unchanged+=1; continue
                b=backup/rel; b.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(target,b); changed+=1
            else: added+=1
            target.parent.mkdir(parents=True,exist_ok=True)
            tmp=target.parent/f'.{target.name}.{os.getpid()}.update.tmp'
            tmp.write_bytes(data); os.replace(tmp,target); copied.append(rel.as_posix())
    backup.mkdir(parents=True,exist_ok=True)
    result={'updated_at':datetime.now().isoformat(timespec='seconds'),'source_zip':str(zip_path),'changed':changed,'added':added,'unchanged':unchanged,'skipped_protected':skipped,'copied':copied,'backup_dir':str(backup)}
    (backup/'update_manifest.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    logdir=package_root/'updates'; logdir.mkdir(parents=True,exist_ok=True)
    (logdir/'last_update.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    return result


def _code_files(root: Path):
    allowed_roots={'app','docs','tests','config'}
    allowed_top={'README.txt','RUN_GUI.bat','REPAIR_PACKAGES.vbs','Launch_Downloadly_GUI.vbs','VERSION.txt'}
    for p in root.rglob('*'):
        if not p.is_file(): continue
        rel=p.relative_to(root)
        if _skip_rel(rel): continue
        if len(rel.parts)==1:
            if rel.name in allowed_top: yield p,rel
        elif rel.parts[0] in allowed_roots:
            if rel.as_posix()=='config/urls.txt': continue
            yield p,rel

def _diagnostic_summary(root: Path) -> dict:
    data=root/'data'; state=data/'state'; report={
        'created_at':datetime.now().isoformat(timespec='seconds'), 'app_version':'',
        'python':sys.version.split()[0], 'platform':platform.platform(),
        'paths':{'package_root':str(root)}, 'counts':{}, 'state_files':{}
    }
    try: report['app_version']=(root/'VERSION.txt').read_text(encoding='utf-8').strip()
    except Exception: pass
    for label,path in [('html_archive',data/'html_archive'),('images',data/'images'),('listing_archive',data/'listing_archive')]:
        try: report['counts'][label]=sum(1 for p in path.rglob('*') if p.is_file()) if path.exists() else 0
        except Exception: report['counts'][label]=None
    for name in ('run_progress.json','topic_progress.json'):
        p=state/name
        if p.exists():
            try: report['state_files'][name]=json.loads(p.read_text(encoding='utf-8-sig',errors='replace'))
            except Exception: report['state_files'][name]={'read_error':True}
    return report


def create_support_package(package_root: Path|str, output_dir: Path|str, mode: str) -> Path:
    """Create code-only or code+diagnostic/logs ZIP for support/debugging."""
    root=Path(package_root).resolve(); out=Path(output_dir).resolve(); out.mkdir(parents=True,exist_ok=True)
    if mode not in {'code','diagnostic'}: raise ValueError('mode must be code or diagnostic')
    version='unknown'
    try: version=(root/'VERSION.txt').read_text(encoding='utf-8').strip()
    except Exception: pass
    zip_path=out/f'downloadly_support_{mode}_v{version}_{_stamp()}.zip'
    top=f'downloadly_support_{mode}_v{version}'
    with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
        for p,rel in _code_files(root): z.write(p,f'{top}/{rel.as_posix()}')
        if mode=='diagnostic':
            # Logs are useful for debugging. Collected HTML/images/reports/database and cookie snapshot stay excluded.
            for logroot in (root/'logs', root/'data'/'logs'):
                if logroot.exists():
                    for p in logroot.rglob('*'):
                        if p.is_file() and p.stat().st_size <= 10*1024*1024:
                            rel=p.relative_to(root); z.write(p,f'{top}/{rel.as_posix()}')
            for name in ('run_progress.json','topic_progress.json'):
                p=root/'data'/'state'/name
                if p.exists(): z.write(p,f'{top}/data/state/{name}')
            z.writestr(f'{top}/diagnostics.json',json.dumps(_diagnostic_summary(root),ensure_ascii=False,indent=2))
    return zip_path


def main(argv=None):
    ap=argparse.ArgumentParser(description='Downloadly package updater/support packager')
    sp=ap.add_subparsers(dest='command',required=True)
    up=sp.add_parser('update'); up.add_argument('--package-root',required=True); up.add_argument('--zip',required=True)
    su=sp.add_parser('support'); su.add_argument('--package-root',required=True); su.add_argument('--output-dir',required=True); su.add_argument('--mode',choices=['code','diagnostic'],required=True)
    a=ap.parse_args(argv)
    if a.command=='update': result=apply_update_zip(a.package_root,a.zip); print(json.dumps(result,ensure_ascii=False))
    else: print(str(create_support_package(a.package_root,a.output_dir,a.mode)))
    return 0

if __name__=='__main__': raise SystemExit(main())

[executed on device: Murali (27a4e370-9282-4fd1-98d2-8172581061df)]