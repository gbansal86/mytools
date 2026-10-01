#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, subprocess, sys
from datetime import datetime
from pathlib import Path
from xml.sax.saxutils import escape

TASK_DEFAULT='Downloadly Catalog Manager V30'

def _bool(v): return 'true' if bool(v) else 'false'

def _start_boundary(start_time: str) -> str:
    try:
        h,m=map(int,start_time.split(':'))
    except Exception:
        h,m=2,0
    now=datetime.now()
    return now.replace(hour=h,minute=m,second=0,microsecond=0).isoformat(timespec='seconds')

def _vbs_quote(value: str) -> str:
    return str(value).replace('"','""')

def prepare_launcher(package_root: Path|str, data_dir: Path|str, config_path: Path|str) -> Path:
    root=Path(package_root).resolve(); data=Path(data_dir).resolve(); cfg=Path(config_path).resolve()
    state=data/'state'; state.mkdir(parents=True,exist_ok=True)
    pyw=root/'runtime'/'.venv'/'Scripts'/'pythonw.exe'
    if not pyw.exists():
        pyw=root/'runtime'/'.venv'/'Scripts'/'python.exe'
    script=root/'app'/'background_scheduler.py'
    launcher=state/'downloadly_background_task.vbs'
    cmd=f'"{pyw}" "{script}" --config "{cfg}"'
    launcher.write_text('Set sh = CreateObject("WScript.Shell")\r\nsh.Run "'+_vbs_quote(cmd)+'", 0, False\r\n',encoding='utf-8-sig')
    return launcher

def build_task_xml(package_root: Path|str, data_dir: Path|str, cfg: dict) -> str:
    root=Path(package_root).resolve(); data=Path(data_dir).resolve()
    config_path=Path(cfg.get('config_path') or data/'state'/'background_schedule.json').resolve()
    launcher=data/'state'/'downloadly_background_task.vbs'
    command=os.path.join(os.environ.get('SystemRoot','C:\\Windows'),'System32','wscript.exe')
    task_name=str(cfg.get('task_name') or TASK_DEFAULT)
    return f'''<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>{escape(task_name)} - background new-content check via background_scheduler.py</Description></RegistrationInfo>
  <Triggers><CalendarTrigger><StartBoundary>{_start_boundary(str(cfg.get('start_time') or '02:00'))}</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger></Triggers>
  <Principals><Principal id="Author"><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>false</AllowHardTerminate><StartWhenAvailable>{_bool(cfg.get('start_when_available',True))}</StartWhenAvailable><RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable><WakeToRun>{_bool(cfg.get('wake_to_run',False))}</WakeToRun><ExecutionTimeLimit>PT0S</ExecutionTimeLimit><Priority>7</Priority><Hidden>true</Hidden></Settings>
  <Actions Context="Author"><Exec><Command>{escape(command)}</Command><Arguments>//B //Nologo &quot;{escape(str(launcher))}&quot;</Arguments><WorkingDirectory>{escape(str(root))}</WorkingDirectory></Exec></Actions>
</Task>'''

def install_task(package_root: Path|str, data_dir: Path|str, config_path: Path|str) -> dict:
    cfg=json.loads(Path(config_path).read_text(encoding='utf-8-sig'))
    cfg['config_path']=str(Path(config_path).resolve())
    launcher=prepare_launcher(package_root,data_dir,config_path)
    xml=build_task_xml(package_root,data_dir,cfg)
    xml_path=Path(data_dir)/'state'/'downloadly_background_task.xml'
    xml_path.write_text(xml,encoding='utf-16')
    if os.name!='nt':
        return {'installed':False,'platform':'non-windows','xml':str(xml_path),'launcher':str(launcher)}
    task=str(cfg.get('task_name') or TASK_DEFAULT)
    cp=subprocess.run(['schtasks','/Create','/TN',task,'/XML',str(xml_path),'/F'],capture_output=True,text=True)
    if cp.returncode!=0: raise RuntimeError(cp.stderr.strip() or cp.stdout.strip() or 'schtasks create failed')
    return {'installed':True,'task_name':task,'xml':str(xml_path),'launcher':str(launcher),'message':cp.stdout.strip()}

def _task_action(config_path: Path|str, action: str) -> dict:
    cfg=json.loads(Path(config_path).read_text(encoding='utf-8-sig')); task=str(cfg.get('task_name') or TASK_DEFAULT)
    if os.name!='nt': return {'ok':False,'platform':'non-windows','task_name':task,'action':action}
    args={'disable':['/Change','/TN',task,'/Disable'],'enable':['/Change','/TN',task,'/Enable'],'run':['/Run','/TN',task],'delete':['/Delete','/TN',task,'/F']}[action]
    cp=subprocess.run(['schtasks',*args],capture_output=True,text=True)
    if cp.returncode!=0: raise RuntimeError(cp.stderr.strip() or cp.stdout.strip() or f'schtasks {action} failed')
    return {'ok':True,'task_name':task,'action':action,'message':cp.stdout.strip()}

def main(argv=None):
    p=argparse.ArgumentParser(); sp=p.add_subparsers(dest='cmd',required=True)
    ins=sp.add_parser('install'); ins.add_argument('--package-root',required=True); ins.add_argument('--data-dir',required=True); ins.add_argument('--config',required=True)
    for name in ('disable','enable','run','delete'):
        x=sp.add_parser(name); x.add_argument('--config',required=True)
    a=p.parse_args(argv)
    result=install_task(a.package_root,a.data_dir,a.config) if a.cmd=='install' else _task_action(a.config,a.cmd)
    print(json.dumps(result,ensure_ascii=False,indent=2)); return 0

if __name__=='__main__': raise SystemExit(main())
