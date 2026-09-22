"""Similarity scoring, duplicate grouping, and report generation."""
from __future__ import annotations
import csv, math
from collections import defaultdict
from pathlib import Path
from vdf_core import VideoInfo,SAMPLE_POSITIONS,frame_hash_at

DURATION_TOLERANCE_PERCENT=5.0; DURATION_TOLERANCE_SECONDS=15.0
NEARBY_OFFSETS_SECONDS=[-10,-5,0,5,10]; MAX_FRAME_HASH_DISTANCE=10
MIN_MATCHED_SAMPLE_RATIO=.72; VERY_LIKELY_RATIO=.82; ALMOST_CERTAIN_RATIO=.91

def hamming(a:str,b:str)->int:return 64 if not a or not b else (int(a,16)^int(b,16)).bit_count()
def duration_close(a:float,b:float)->bool:
    d=abs(a-b); return d<=DURATION_TOLERANCE_SECONDS or d/max(a,b,1)*100<=DURATION_TOLERANCE_PERCENT
def aspect_close(a:VideoInfo,b:VideoInfo)->bool:
    if not a.width or not a.height or not b.width or not b.height:return True
    return abs(a.width/a.height-b.width/b.height)<=.18

def basic_similarity(a:VideoInfo,b:VideoInfo):
    ds=[hamming(x,y) for x,y in zip(a.fingerprint,b.fingerprint) if x and y]
    if not ds:return 0.0,0,0,64.0
    m=sum(d<=MAX_FRAME_HASH_DISTANCE for d in ds); return m/len(ds),m,len(ds),sum(ds)/len(ds)

def refined_similarity(a:VideoInfo,b:VideoInfo):
    matched=compared=total=0
    for pos in SAMPLE_POSITIONS:
        ha=frame_hash_at(Path(a.path),a.duration*pos)
        if not ha:continue
        expected=b.duration*pos; best=64
        for off in NEARBY_OFFSETS_SECONDS:
            t=min(max(0,expected+off),max(0,b.duration-.05)); hb=frame_hash_at(Path(b.path),t)
            if hb: best=min(best,hamming(ha,hb))
            if best==0:break
        if best<64: compared+=1; total+=best; matched+=int(best<=MAX_FRAME_HASH_DISTANCE)
    return (matched/compared,matched,compared,total/compared) if compared else (0.0,0,0,64.0)

def score(ratio:float,avg:float,a:VideoInfo,b:VideoInfo)->float:
    dp=abs(a.duration-b.duration)/max(a.duration,b.duration,1)
    return round(min(100,ratio*90+max(0,1-min(dp/.05,1))*7+max(0,1-min(avg/16,1))*3),2)
def classify(r:float)->str:
    if r>=ALMOST_CERTAIN_RATIO:return 'ALMOST CERTAIN DUPLICATE'
    if r>=VERY_LIKELY_RATIO:return 'VERY LIKELY DUPLICATE'
    return 'POSSIBLE DUPLICATE'

def compare(a:VideoInfo,b:VideoInfo):
    r,m,c,d=basic_similarity(a,b)
    if r>=.45:
        rr,rm,rc,rd=refined_similarity(a,b)
        if rr>r or (math.isclose(rr,r) and rd<d):r,m,c,d=rr,rm,rc,rd
    if r<MIN_MATCHED_SAMPLE_RATIO:return None
    return r,m,c,d,score(r,d,a,b),classify(r)

class DSU:
    def __init__(self,n):self.p=list(range(n));self.r=[0]*n
    def find(self,x):
        while self.p[x]!=x:self.p[x]=self.p[self.p[x]];x=self.p[x]
        return x
    def union(self,a,b):
        a,b=self.find(a),self.find(b)
        if a==b:return
        if self.r[a]<self.r[b]:a,b=b,a
        self.p[b]=a
        if self.r[a]==self.r[b]:self.r[a]+=1

def human_size(n:int)->str:
    v=float(n)
    for u in ['B','KB','MB','GB','TB']:
        if v<1024 or u=='TB':return f'{v:.2f} {u}'
        v/=1024

def write_reports(videos:list[VideoInfo],matches:list[dict],root:Path)->None:
    csv_path=root/'duplicate_report.csv'; txt_path=root/'duplicate_groups.txt'
    fields=['classification','score','visual_match_ratio','matched_samples','compared_samples','avg_hash_distance','duration_diff_seconds','video_a','size_a','duration_a','resolution_a','video_b','size_b','duration_b','resolution_b']
    with csv_path.open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=fields);w.writeheader()
        for row in sorted(matches,key=lambda x:(-x['score'],x['video_a'].casefold())):w.writerow(row)
    d=DSU(len(videos));idx={v.path:i for i,v in enumerate(videos)}
    for m in matches:d.union(idx[m['video_a']],idx[m['video_b']])
    groups=defaultdict(list)
    for i,v in enumerate(videos):groups[d.find(i)].append(v)
    groups=[g for g in groups.values() if len(g)>=2];groups.sort(key=lambda g:(-len(g),min(v.path.casefold() for v in g)))
    with txt_path.open('w',encoding='utf-8') as f:
        f.write('VIDEO DUPLICATE FINDER REPORT\n'+'='*80+'\n\n')
        f.write(f'Videos fingerprinted: {len(videos)}\nDuplicate candidate pairs: {len(matches)}\nDuplicate groups: {len(groups)}\n\n')
        f.write('IMPORTANT: Suggested keeper is only a convenience suggestion. Review videos before removing anything.\n\n')
        for n,g in enumerate(groups,1):
            k=max(g,key=lambda v:(v.width*v.height,v.duration,v.size))
            f.write('='*80+f'\nGROUP {n} - {len(g)} files\n'+'='*80+'\n')
            f.write(f'Suggested keeper: {k.path}\n  {k.width}x{k.height} | {human_size(k.size)} | {k.duration:.2f}s\n\n')
            for v in sorted(g,key=lambda x:x.path.casefold()):
                tag='KEEP' if v.path==k.path else 'DUP?';f.write(f'[{tag}] {v.path}\n       {v.width}x{v.height} | {human_size(v.size)} | {v.duration:.2f}s\n')
            f.write('\n')
    print('\nCreated:',csv_path);print('Created:',txt_path)
