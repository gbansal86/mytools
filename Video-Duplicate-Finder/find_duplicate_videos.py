#!/usr/bin/env python3
"""Main command-line entry point for Video Duplicate Finder."""
from __future__ import annotations
import os,time
from collections import defaultdict
from pathlib import Path
from vdf_core import VIDEO_EXTENSIONS,ensure_tools,get_video_info,load_cache,save_cache
from vdf_match import aspect_close,compare,duration_close,write_reports

PATHS_FILE='video_paths.txt';CACHE_FILE='video_fingerprint_cache.json';BUCKET_SECONDS=30

def roots_from_file(path:Path)->list[Path]:
    if not path.exists():path.write_text('# One folder per line\nD:\\Videos\n',encoding='utf-8');print('Created video_paths.txt; edit it and rerun.');raise SystemExit(0)
    roots=[]
    for raw in path.read_text(encoding='utf-8-sig').splitlines():
        s=raw.strip().strip('"')
        if not s or s.startswith('#'):continue
        p=Path(s)
        if p.exists() and p.is_dir():roots.append(p)
        else:print('WARNING path not found; skipped:',s)
    return roots

def discover(roots:list[Path])->list[Path]:
    found={}
    for root in roots:
        print('Scanning:',root)
        for dp,_,names in os.walk(root):
            for name in names:
                p=Path(dp)/name
                if p.suffix.lower() in VIDEO_EXTENSIONS:
                    try:key=str(p.resolve()).casefold()
                    except OSError:key=str(p.absolute()).casefold()
                    found[key]=p
    return sorted(found.values(),key=lambda p:str(p).casefold())

def row_for(a,b,result):
    r,m,c,d,s,label=result
    return {'classification':label,'score':s,'visual_match_ratio':round(r,4),'matched_samples':m,'compared_samples':c,'avg_hash_distance':round(d,2),'duration_diff_seconds':round(abs(a.duration-b.duration),2),'video_a':a.path,'size_a':a.size,'duration_a':round(a.duration,2),'resolution_a':f'{a.width}x{a.height}','video_b':b.path,'size_b':b.size,'duration_b':round(b.duration,2),'resolution_b':f'{b.width}x{b.height}'}

def main()->int:
    started=time.time();root=Path(__file__).resolve().parent;os.chdir(root)
    print('='*72+'\nVIDEO DUPLICATE FINDER\n'+'='*72);ensure_tools()
    roots=roots_from_file(root/PATHS_FILE)
    if not roots:print('No valid search folders configured.');return 1
    files=discover(roots);print(f'\nFound {len(files)} video files.\n')
    if len(files)<2:return 0
    cache_path=root/CACHE_FILE;cache=load_cache(cache_path);videos=[]
    for i,p in enumerate(files,1):
        print(f'[{i}/{len(files)}] {p}');info=get_video_info(p,cache)
        if info:videos.append(info)
        if i%10==0:save_cache(cache_path,cache)
    save_cache(cache_path,cache)
    buckets=defaultdict(list)
    for i,v in enumerate(videos):buckets[int(v.duration//BUCKET_SECONDS)].append(i)
    checked=set();matches=[];print(f'\nComparing {len(videos)} usable videos...')
    for ia,a in enumerate(videos):
        bkt=int(a.duration//BUCKET_SECONDS); candidates=[]
        for x in range(bkt-2,bkt+3):candidates.extend(buckets.get(x,[]))
        for ib in candidates:
            if ib<=ia or (ia,ib) in checked:continue
            checked.add((ia,ib));b=videos[ib]
            if not duration_close(a.duration,b.duration) or not aspect_close(a,b):continue
            result=compare(a,b)
            if result:
                print(f'MATCH {result[4]:5.1f}% | {result[5]}\n  A: {a.path}\n  B: {b.path}')
                matches.append(row_for(a,b,result))
    write_reports(videos,matches,root)
    print(f'\nFinished in {(time.time()-started)/60:.1f} minutes. No videos were moved or deleted.')
    return 0

if __name__=='__main__':
    try:raise SystemExit(main())
    except KeyboardInterrupt:print('\nCancelled.');raise SystemExit(130)
