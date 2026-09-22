#!/usr/bin/env python3
"""Local-only HTTP server used to review and recycle duplicate candidates."""
from __future__ import annotations
import json,mimetypes,os,re,socket,threading,urllib.parse,webbrowser
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from review_data import log_action,parse_report,recycle
from review_ui import build_page

ROOT=Path(__file__).resolve().parent;DEFAULT_REPORT=ROOT/'duplicate_groups.txt';POINTER=ROOT/'report_path.txt';LOG=ROOT/'deleted_files_log.csv'
REPORT=DEFAULT_REPORT;GROUPS={};ITEMS={}
def resolve_report():
    if POINTER.exists():
        for raw in POINTER.read_text(encoding='utf-8-sig').splitlines():
            s=raw.strip().strip('"')
            if s and not s.startswith('#') and Path(s).exists():return Path(s)
    return DEFAULT_REPORT
def reload_state():
    global GROUPS,ITEMS;GROUPS,ITEMS=parse_report(REPORT)
def free_port():
    for p in range(8765,8865):
        with socket.socket() as s:
            try:s.bind(('127.0.0.1',p));return p
            except OSError:pass
    raise RuntimeError('No free local port.')
def reply(h,status,payload):
    b=json.dumps(payload).encode();h.send_response(status);h.send_header('Content-Type','application/json');h.send_header('Content-Length',str(len(b)));h.end_headers();h.wfile.write(b)
def media(h,path:Path):
    if not path.exists():return h.send_error(404)
    size=path.stat().st_size;start,end,status=0,size-1,200;m=re.match(r'bytes=(\d*)-(\d*)',h.headers.get('Range',''))
    if m:
        if m.group(1):start=int(m.group(1))
        if m.group(2):end=int(m.group(2))
        start=max(0,min(start,size-1));end=max(start,min(end,size-1));status=206
    length=end-start+1;h.send_response(status);h.send_header('Content-Type',mimetypes.guess_type(str(path))[0] or 'application/octet-stream');h.send_header('Accept-Ranges','bytes');h.send_header('Content-Length',str(length))
    if status==206:h.send_header('Content-Range',f'bytes {start}-{end}/{size}')
    h.end_headers()
    try:
        with path.open('rb') as f:
            f.seek(start);left=length
            while left:
                chunk=f.read(min(1024*1024,left))
                if not chunk:break
                h.wfile.write(chunk);left-=len(chunk)
    except (BrokenPipeError,ConnectionResetError):pass
class Handler(BaseHTTPRequestHandler):
    def log_message(self,fmt,*args):
        if '/media/' not in str(args):super().log_message(fmt,*args)
    def body(self):
        try:return json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))).decode())
        except Exception:return {}
    def do_GET(self):
        p=urllib.parse.urlparse(self.path).path
        if p=='/':
            reload_state();b=build_page(REPORT,GROUPS).encode();self.send_response(200);self.send_header('Content-Type','text/html; charset=utf-8');self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b);return
        if p.startswith('/media/'):
            x=ITEMS.get(p.split('/media/',1)[1]);return media(self,x['path']) if x else self.send_error(404)
        self.send_error(404)
    def do_POST(self):
        if self.path=='/open-folder':
            x=ITEMS.get(str(self.body().get('id','')))
            if not x:return reply(self,404,{'ok':False,'message':'Unknown video.'})
            try:os.startfile(str(x['path'].parent));return reply(self,200,{'ok':True})
            except Exception as e:return reply(self,500,{'ok':False,'message':str(e)})
        if self.path!='/process':return self.send_error(404)
        ids=self.body().get('ids',[]);sel=[ITEMS[i] for i in ids if i in ITEMS and ITEMS[i]['path'].exists()];chosen={x['id'] for x in sel};blocked=set()
        for g in GROUPS.values():
            existing=[x for x in g if x['path'].exists()];picked=[x for x in existing if x['id'] in chosen]
            if existing and len(picked)==len(existing):blocked.update(x['id'] for x in picked)
        done=failed=0
        for x in sel:
            if x['id'] in blocked:continue
            ok,msg=recycle(x['path']);log_action(LOG,x,ok,msg);done+=int(ok);failed+=int(not ok)
        reload_state();reply(self,200,{'ok':True,'processed':done,'failed':failed,'blocked':sorted(blocked)})
def main():
    global REPORT;REPORT=resolve_report()
    if not REPORT.exists():print('duplicate_groups.txt not found. Run the scanner first.');input('Press Enter...');return 2
    reload_state()
    if not ITEMS:print('No video entries parsed.');input('Press Enter...');return 3
    port=free_port();url=f'http://127.0.0.1:{port}/';srv=ThreadingHTTPServer(('127.0.0.1',port),Handler)
    print(f'Report: {REPORT}\nGroups: {len(GROUPS)} | Videos: {len(ITEMS)}\nOpening: {url}\nKeep this window open; Ctrl+C stops it.')
    threading.Timer(.7,lambda:webbrowser.open(url)).start()
    try:srv.serve_forever()
    except KeyboardInterrupt:pass
    finally:srv.server_close()
    return 0
if __name__=='__main__':raise SystemExit(main())
