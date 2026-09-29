# Universal Windows App Test Recorder

## Status

Idea / design specification.

## Goal

Build one reusable Windows testing engine that can test many different desktop applications without writing a separate automation program for every app.

The universal engine reads an **App Execution Plan** that describes how a specific application should be launched, exercised, validated, recorded, and cleaned up.

The same engine should be reusable for apps built with Python/Tkinter, PySide6/Qt, .NET, PowerShell GUIs, Win32, Electron, and other Windows desktop frameworks whenever their controls can be exposed through Windows UI Automation or controlled through fallback methods.

---

## Core Concept

```text
Universal Test Engine
        |
        +-- App Execution Plan
        |     +-- launch instructions
        |     +-- feature/workflow list
        |     +-- test inputs
        |     +-- expected results
        |     +-- validation rules
        |     +-- safety rules
        |     +-- cleanup rules
        |
        +-- UI Automation
        +-- Screen Recording
        +-- Mouse / Click Visualization
        +-- On-screen Step Overlay
        +-- Screenshots
        +-- Crash Detection
        +-- Resource Monitoring
        +-- Validation Engine
        +-- HTML Test Report
```

The engine remains generic. App-specific behavior lives in execution-plan files.

---

## Main Requirements

### 1. Universal Engine

The engine should understand generic actions such as:

- launch an application
- attach to an already-running process
- wait for a window
- click a button
- double-click a control
- type into a field
- clear a field
- select a combo-box item
- select a list/table row
- switch a tab
- open menus
- press keyboard shortcuts
- choose a file
- choose a folder
- drag and drop
- scroll
- wait for a condition
- take a screenshot
- read control text
- inspect application controls
- verify files/folders
- verify text
- verify process state
- verify database/output state through pluggable validators
- record PASS / FAIL / SKIP / WARNING
- retry failed steps
- execute conditional branches
- perform cleanup

The engine should not need source-code changes when a new app is added.

---

## 2. App Execution Plan

Each application gets its own execution plan.

Suggested layout:

```text
ideas/
└── universal_app_test_recorder/
    ├── README.md
    ├── sample_execution_plan.yaml
    └── future/
```

Later, real application profiles could live under:

```text
plans/
├── telegram_catalog_manager/
│   ├── execution_plan.yaml
│   ├── test_data/
│   └── expected_results/
├── video_hoarder/
├── duplicate_video_finder/
├── archive_extractor/
├── usb_port_explorer/
└── google_drive_downloader/
```

---

## 3. Execution Plan Sections

Each execution plan should support these major sections.

### App Definition

Describe:

- application name
- executable path
- command-line arguments
- working directory
- expected process name
- expected main-window title
- startup timeout
- shutdown method
- administrator requirement
- environment variables
- required services or dependencies

### Test Environment

Describe:

- test data folders
- sample files
- temporary output directory
- test database
- test account when required
- network requirements
- cleanup folder
- baseline configuration
- restore/rollback instructions

### Workflows

Describe real user workflows instead of only isolated button tests.

Example:

```text
Select folder
    ->
Scan
    ->
Wait for completion
    ->
Verify results
    ->
Generate report
    ->
Verify output file
```

### Validation

The engine should support validators such as:

- window exists
- window disappeared
- text equals
- text contains
- control enabled/disabled
- table row count
- file exists
- folder exists
- file size greater than N
- file modified after test start
- CSV contains columns
- CSV has rows
- JSON is valid
- HTML exists and contains expected text
- SQLite query returns expected value
- process running/stopped
- application did not crash
- log contains expected text
- log does not contain error patterns

### Safety

Every plan should identify unsafe actions.

Examples:

- Delete
- Remove
- Format
- Uninstall
- Reset
- Send
- Publish
- Pay
- Purchase
- Upload
- destructive database operations

The engine should support:

- never click
- require approval
- allow only in sandbox
- allow only when test-mode flag is active

---

## 4. Test Modes

### Explorer Mode

Analyze the application and discover accessible controls.

Possible output:

```text
Windows:      3
Buttons:     24
Text fields:  5
Checkboxes:  11
Tabs:         4
Menus:        8
```

Export:

- automation ID
- control type
- visible text
- parent window
- enabled state
- screen coordinates
- UI Automation properties

This information can help create execution plans.

### Smoke Test

Fast validation of critical functionality:

- application starts
- main window appears
- important controls are available
- critical workflow opens
- no immediate crash

### Full Profile Test

Execute all workflows defined in the execution plan.

### Demo Recording

Run workflows slowly enough for humans to follow.

Features:

- smooth visible mouse movement
- click indicators
- pauses between actions
- annotations
- optional zoom
- human-readable descriptions

The output can double as a demo/tutorial video.

### Record New Workflow

A user performs a workflow once.

The recorder observes:

- clicks
- keyboard input
- UI Automation target
- file/folder selections
- window transitions

It generates an initial execution-plan sequence automatically.

Example:

```yaml
- click: Browse
- choose_folder: E:\Videos
- click: Scan
- wait_for_text: Scan Complete
- click: Generate Report
```

The user can then add validation rules.

### Replay Workflow

Run a previously recorded workflow without a person.

---

## 5. On-Screen Recording Overlay

The video should clearly show what the automation is doing.

Example:

```text
AUTOMATED APP TEST
-----------------------------
App: Duplicate Video Finder
Test: Full Scan
Step: 8 / 24

Current action:
Clicking "Scan"

Expected:
Scan starts and completes

Status:
TESTING...

Elapsed:
00:01:48
```

After validation:

```text
PASS

Videos scanned: 52
Duplicate groups: 7
HTML report: Created
Errors: 0
```

The overlay should optionally show:

- application name
- test-suite name
- workflow name
- current step
- action being performed
- input being supplied
- expected result
- current status
- elapsed time
- pass/fail totals
- warning count
- retry count

Sensitive fields such as passwords or tokens must be masked.

---

## 6. Screen Recording

Recommended options:

### FFmpeg

Primary local recording engine.

Capture:

- application window or desktop
- mouse pointer
- optional audio
- configurable frame rate
- optional recording region

### OBS Integration

Optional later integration for higher-quality demo recordings.

The engine should support:

- start recording before test execution
- add markers/timestamps for each test
- stop recording after cleanup
- map failures to video timestamps

Example report entry:

```text
TEST-012: Recycle Bin
Status: FAIL
Failure video timestamp: 00:04:17
Screenshot: TEST-012-failure.png
```

---

## 7. Mouse and Action Visualization

For demo mode:

- smoothly move pointer to controls
- draw a temporary circle around the target
- flash on click
- optionally show left-click/right-click icon
- display short action caption

Example:

```text
Moving to: Export CSV
Click: Export CSV
Waiting for file...
PASS
```

For fast regression tests these animations can be disabled.

---

## 8. Automation Backends

Use a layered strategy.

### Primary: Windows UI Automation / pywinauto

Use whenever possible because it targets controls semantically rather than only by coordinates.

Preferred selectors:

1. automation ID
2. control type + name
3. parent relationship
4. stable accessible properties
5. coordinates only as fallback

### Secondary: PyAutoGUI

Use for:

- mouse
- keyboard
- coordinate-based interactions
- fallback controls
- screenshots

### Optional Visual Fallback

OpenCV/image matching can be used when the UI is inaccessible through Windows UI Automation.

Visual matching should be fallback-only because themes, scaling, DPI, window size, and UI changes can break image-based automation.

---

## 9. Validation Engine

A test is only useful when it verifies results.

Bad test:

```text
Click Export CSV
PASS
```

Better test:

```text
Click Export CSV
Wait for completion
Verify a new CSV was created
Verify file size > 0
Verify expected columns exist
Verify row count > 0
PASS
```

The validation engine should support plugin validators so application-specific checks can be added without changing the core engine.

Potential validators:

- filesystem validator
- CSV validator
- JSON validator
- HTML validator
- SQLite validator
- process validator
- log validator
- UI-control validator
- image validator
- custom Python validator

---

## 10. Conditional Logic

Execution plans need branching.

Example:

```yaml
- if:
    window_exists: Database Migration Required
  then:
    - click: Migrate
    - wait_for_text: Migration Complete
  else:
    - continue: true
```

Other conditions:

- file exists
- control exists
- control enabled
- text present
- process running
- variable equals value
- previous test passed/failed

---

## 11. Retry and Timeout Logic

Support per-action and per-test retry rules.

Example:

```yaml
retry:
  count: 3
  delay_seconds: 5
```

Every wait should have a timeout to prevent hanging forever.

Timeouts can exist at:

- application startup
- window appearance
- individual action
- workflow
- entire test suite

---

## 12. Failure Handling

On failure the engine should automatically capture evidence.

Recommended default:

```yaml
on_failure:
  - screenshot
  - save_ui_tree
  - save_logs
  - save_process_state
  - save_resource_usage
  - record_video_timestamp
  - continue_next_test
```

Critical tests may instead use:

```yaml
on_failure:
  - capture_evidence
  - stop_suite
```

---

## 13. Crash Detection

Monitor:

- target process unexpectedly exits
- Windows crash/error dialog
- application becomes unresponsive
- child process exits unexpectedly
- fatal keywords in logs

When a crash is detected:

1. capture screenshot
2. record process information
3. copy recent application logs
4. note video timestamp
5. mark active test as failed
6. optionally restart application
7. continue remaining independent tests

---

## 14. CPU / RAM / GPU Monitoring

Use `psutil` for:

- CPU
- RAM
- process memory
- disk I/O
- process/thread state

Optional GPU support can later use vendor APIs or Windows counters.

Record resource samples during tests.

Example report:

```text
Peak RAM: 1.8 GB
Average CPU: 24%
Peak CPU: 83%
Test duration: 02:43
```

This helps detect performance regressions.

---

## 15. Reporting

Generate one self-contained HTML report where practical.

Recommended dashboard:

```text
Total Tests:  52
Passed:       47
Failed:        3
Skipped:       2
Warnings:      4

Success Rate: 90.4%
Duration:     12m 18s
```

Each test should include:

- test ID
- test name
- workflow
- status
- duration
- action log
- expected result
- actual result
- screenshot links
- failure screenshot
- video timestamp
- error/exception
- retry history
- related output files

Add filters:

- All
- Passed
- Failed
- Warnings
- Skipped

The report should also provide a chronological execution timeline.

---

## 16. Test Data Isolation

Testing must avoid damaging normal user data.

Preferred model:

```text
test_workspace/
├── input/
├── output/
├── temp/
├── database/
└── logs/
```

Before each suite:

1. prepare clean test workspace
2. copy known input samples
3. initialize test database/configuration
4. launch app against test data

After test:

1. preserve evidence
2. optionally archive results
3. clean temporary files
4. restore configuration

---

## 17. Reusable Common Plans

Create reusable workflow modules.

Possible library:

```text
common/
├── launch_app.yaml
├── close_app.yaml
├── choose_file.yaml
├── choose_folder.yaml
├── verify_csv.yaml
├── verify_json.yaml
├── verify_html.yaml
├── verify_sqlite.yaml
├── wait_for_completion.yaml
├── capture_failure.yaml
└── crash_detection.yaml
```

Application plans can include these rather than duplicate steps.

---

## 18. Suggested GUI

```text
UNIVERSAL WINDOWS APP TESTER
------------------------------------------------

Application:
[E:\Apps\MyApp.exe] [Browse]

Execution Plan:
[plans\my_app\execution_plan.yaml] [Browse]

Mode:
(*) Auto Explore
( ) Smoke Test
( ) Full Profile Test
( ) Record New Workflow
( ) Replay Workflow
( ) Demo Recording

Recording
[x] Record video
[x] Show mouse movement
[x] Show action overlay
[x] Capture screenshots
[x] Generate HTML report

Diagnostics
[x] Detect crashes
[x] CPU/RAM monitoring
[x] Save application logs
[x] Save UI tree on failure

Safety
[x] Block destructive actions
[x] Use test workspace
[x] Mask sensitive input

[ANALYZE APP]
[START TEST]
[PAUSE]
[STOP]
[OPEN REPORT]
```

During execution:

```text
Current: Step 18 / 52
Workflow: Incremental Sync
Action: Clicking Download Latest N
Input: 500
Status: TESTING

Passed: 16
Failed: 1
Warnings: 2
Pending: 33
```

---

## 19. Proposed Technology Stack

Initial version:

- Python 3
- pywinauto
- Windows UI Automation
- PyAutoGUI
- psutil
- FFmpeg
- pytest
- PyYAML
- Jinja2 for HTML reporting
- SQLite for run history
- OpenCV only as visual fallback

GUI options:

- PySide6/Qt preferred for a polished Windows application
- Tkinter acceptable for a lightweight prototype

---

## 20. Run History Database

Store historical results in SQLite.

Possible tables:

- applications
- execution_plans
- test_runs
- test_cases
- test_results
- screenshots
- videos
- resource_samples
- failures

This allows comparison such as:

```text
Version 1.2.1 -> 51/52 passed
Version 1.2.2 -> 48/52 passed
```

and identification of newly introduced regressions.

---

## 21. Automatic App Exploration

The engine should optionally inspect an unknown app and produce an inventory.

Possible output:

```text
Main Window
|
+-- Tab: Scan
|   +-- Button: Browse
|   +-- Edit: Folder
|   +-- Button: Start Scan
|
+-- Tab: Reports
|   +-- Button: Generate HTML
|   +-- Button: Export CSV
|
+-- Menu
    +-- Settings
    +-- Help
```

It can classify controls as:

- probably safe
- unknown
- potentially destructive

Auto exploration should not blindly activate destructive controls.

---

## 22. Execution Plan Generation from Recording

Long-term objective:

```text
Record Me
   ->
User performs workflow once
   ->
Capture UI Automation targets
   ->
Generate YAML
   ->
User reviews expected results
   ->
Save plan
   ->
Replay automatically forever
```

The recorder should prefer semantic selectors rather than absolute screen coordinates.

Example generated selector:

```yaml
target:
  control_type: Button
  name: Scan
  automation_id: btnScan
```

rather than:

```yaml
x: 824
y: 516
```

Coordinates should remain fallback metadata only.

---

## 23. App-Specific Examples

### Duplicate Video Finder

Possible workflow:

1. launch
2. select sample video folder
3. start scan
4. wait for completion
5. confirm number of videos scanned
6. verify duplicate groups
7. generate HTML report
8. verify HTML exists
9. open report
10. verify report loads

### Telegram Content Catalog Manager

Possible workflows:

- account selection
- channel listing
- check totals
- incremental download
- latest-N download
- duplicate detection
- CSV export
- HTML catalog generation
- cross-channel search
- recycle bin
- database verification

Tests must use a controlled test account/test dataset where external actions are involved.

### Archive Extractor

Possible workflow:

1. select known test archive
2. extract
3. verify output structure
4. verify nested archive extraction
5. verify expected file count
6. verify no unexpected failures

### USB Port Explorer

Possible workflow:

1. launch
2. scan ports
3. verify device list appears
4. select device
5. verify friendly name
6. verify PnP path
7. export report

---

## 24. Recommended Development Phases

### Phase 1 - Core Runner

Implement:

- YAML parser
- application launcher
- click/type/select
- waits/timeouts
- screenshots
- PASS/FAIL results
- basic HTML report

### Phase 2 - Recording

Add:

- FFmpeg recording
- test timestamps
- click visualization
- action overlay

### Phase 3 - Validation

Add:

- filesystem
- CSV
- HTML
- JSON
- SQLite
- log
- process validators

### Phase 4 - Explorer

Add:

- UI Automation tree scanner
- control inventory
- selector generator

### Phase 5 - Workflow Recorder

Add:

- record user actions
- convert to execution-plan steps
- selector stabilization
- generated YAML editor

### Phase 6 - Advanced Reliability

Add:

- retry policies
- conditional execution
- reusable modules
- restart-after-crash
- isolated workspaces
- run history
- regression comparison

### Phase 7 - Demo Mode

Add:

- smooth pointer movement
- overlays
- human-readable captions
- optional zoom
- polished recording output

---

## 25. Definition of Success

The project is successful when a new app can be tested with this workflow:

```text
1. Select application executable.
2. Analyze application.
3. Record or create execution plan.
4. Supply controlled test data.
5. Click Start Test.
6. Do not touch mouse/keyboard.
7. Engine performs complete workflow.
8. Engine visibly explains actions in recording.
9. Engine validates actual results.
10. Engine generates PASS/FAIL report with evidence.
11. Same execution plan can be rerun after every app update.
```

The long-term target is:

> Give the tester an app plus an execution plan and receive a repeatable automated test, screen recording, screenshots, diagnostics, and evidence-rich report without requiring a person to manually perform the workflow each time.
