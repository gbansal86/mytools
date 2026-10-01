#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, threading, time
from datetime import datetime, timedelta
from pathlib import Path
import catalog_v23 as catalog


def _parse_hm(value: str, default=(7,0)):
    try: return tuple(map(int,str(value).split(':',1)))
    except Exception: return default

def window_end(now: datetime, start_hm: str, end_hm: str) -> datetime:
    sh,sm=_parse_hm(start_hm,(2,0)); eh,em=_parse_hm(end_hm,(7,0))
    end=now.replace(hour=eh,minute=em,second=0,microsecond=0)
    start_min=sh*60+sm; end_min=eh*60+em; cur=now.hour*60+now.minute
    if end_min<=start_min and cur>=start_min: end += timedelta(days=1)
    elif end<=now: end += timedelta(days=1)
    return end

def _write_json(path: Path, payload: dict):
    path.parent.mkdir(parents=True,exist_ok=True); catalog.legacy.atomic_write_json(path,payload)

def run_cycle(cfg: dict, test_once: bool=False) -> int:
    root=Path(cfg['package_root']); data=Path(cfg['data_dir']); topics=cfg.get('topics') or ['video-tutorials']
    args=[
        '--data-dir',str(data),'--topics',','.join(topics),'--phase','scheduled','--skip-migration','--new-only',
        '--timeout',str(int(cfg.get('timeout',45))), '--workers',str(int(cfg.get('workers',3))), '--block-wait-minutes',str(float(cfg.get('block_wait_minutes',3))),
        '--max-wait-minutes',str(float(cfg.get('max_wait_minutes',30))), '--report-every',str(int(cfg.get('report_every',10))),
        '--report-seconds',str(int(cfg.get('report_seconds',60))), '--max-block-retries',str(int(cfg.get('max_block_retries',1))), '--clear-cookies-before-run','--retry-failed'
    ]
    if cfg.get('increasing_wait'): args.append('--increasing-wait')
    if cfg.get('download_images'): args.append('--download-images')
    if cfg.get('translation')=='argos': args += ['--translation','argos']
    return catalog.main(args)

def main(argv=None):
    ap=argparse.ArgumentParser(); ap.add_argument('--config',required=True); ap.add_argument('--test-once',action='store_true'); a=ap.parse_args(argv)
    cfg=json.loads(Path(a.config).read_text(encoding='utf-8-sig'))
    data=Path(cfg['data_dir']); state=data/'state'; stop_file=state/'stop.requested'
    now=datetime.now(); deadline=now+timedelta(hours=24) if a.test_once else window_end(now,str(cfg.get('start_time','02:00')),str(cfg.get('end_time','07:00')))
    def request_end():
        delay=max(0,(deadline-datetime.now()).total_seconds())
        if delay: time.sleep(delay)
        stop_file.parent.mkdir(parents=True,exist_ok=True); stop_file.touch()
    timer=threading.Thread(target=request_end,daemon=True); timer.start()
    repeat=max(0,int(cfg.get('repeat_minutes',60)))
    runs=0; last_rc=0
    while True:
        if datetime.now()>=deadline and not a.test_once: break
        started=datetime.now(); last_rc=run_cycle(cfg,a.test_once); runs+=1
        _write_json(state/'scheduled_last_run.json',{'updated_at':datetime.now().isoformat(timespec='seconds'),'started_at':started.isoformat(timespec='seconds'),'exit_code':last_rc,'runs_this_window':runs,'topics':cfg.get('topics',[])})
        if a.test_once or repeat<=0: break
        next_run=datetime.now()+timedelta(minutes=repeat)
        if next_run>=deadline: break
        while datetime.now()<next_run:
            if datetime.now()>=deadline: break
            time.sleep(min(5,max(0.2,(next_run-datetime.now()).total_seconds())))
    return last_rc

if __name__=='__main__': raise SystemExit(main())
