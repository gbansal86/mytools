from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'app'))
import catalog_v23 as c


def test_v30_version_and_worker_limit():
    assert c.APP_VERSION == '30.0'
    gui=(ROOT/'app'/'Downloadly_GUI.ps1').read_text(encoding='utf-8-sig')
    src=(ROOT/'app'/'catalog_v23.py').read_text(encoding='utf-8')
    assert '$Workers.Maximum=100' in gui
    assert '$Workers.Value=3' in gui
    assert 'min(int(workers or 1),100)' in src


def test_v30_has_headless_selenium_recovery_and_bounded_gate():
    src=(ROOT/'app'/'catalog_v23.py').read_text(encoding='utf-8')
    req=(ROOT/'app'/'requirements.txt').read_text(encoding='utf-8')
    boot=(ROOT/'app'/'Bootstrap.ps1').read_text(encoding='utf-8-sig')
    assert 'selenium_fallback_gate=threading.BoundedSemaphore(2)' in src
    assert "mode='browser'" in src
    assert 'HEADLESS FALLBACK SUCCESS' in src
    assert 'selenium' in req.lower()
    assert 'openpyxl,selenium' in boot


def test_v30_gui_reattaches_and_does_not_leave_manual_worker_hidden():
    gui=(ROOT/'app'/'Downloadly_GUI.ps1').read_text(encoding='utf-8-sig')
    assert 'function Attach-ExistingWorker' in gui
    assert 'Attached to running worker PID' in gui
    assert "@('pause.requested','stop.requested','cancel.requested')" in gui
    assert 'OK = Stop worker and close' in gui
    assert 'leave worker running' not in gui
    assert 'taskkill.exe' in gui


def test_v30_block_retry_defaults_defer_after_fallback():
    src=(ROOT/'app'/'catalog_v23.py').read_text(encoding='utf-8')
    bg=(ROOT/'app'/'background_scheduler.py').read_text(encoding='utf-8')
    gui=(ROOT/'app'/'Downloadly_GUI.ps1').read_text(encoding='utf-8-sig')
    assert "--max-block-retries',type=int,default=1" in src
    assert "cfg.get('max_block_retries',1)" in bg
    assert "'--max-block-retries','1'" in gui
