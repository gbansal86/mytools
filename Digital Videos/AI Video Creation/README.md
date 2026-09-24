# Digital Videos / AI Video Creation

**This is the canonical parent folder for the AI educational Short production.** The previous root `AI_60_Second_Educational_Video/` folder is being relocated here. The existing PR is a **draft**; this content is not on `main` until the PR is merged.

## Start here
1. [DIGITAL_VIDEO_MASTER_PROMPT.md](00_Project_Brief/DIGITAL_VIDEO_MASTER_PROMPT.md) — permanent instruction, visual quality contract, role review and hard STOP rules. Use this prompt in future conversations.
2. [00_PLAN.md](00_Project_Brief/00_PLAN.md) — stages, release gates and resume logic.
3. [Narration draft and timed shots](02_Scripts/01_SCRIPT_AND_SHOTS.md), [99-word voice draft](02_Scripts/voice_script_v03.txt).
4. [Approved-visual and motion specifications](04_Assets/02_ASSET_AND_ANIMATION_SPEC.md); actual generated concept reference images are available in the conversation package but **have not yet been committed** to this PR.
5. [Silent animatic source](05_Animation/render_animatic.py) and [dependencies](05_Animation/requirements.txt) — runnable *prototype* only, NOT the promised polished 3D/narrated Short.
6. [Creator/viewer second pass](07_QA/05_CREATOR_VIEWER_REVIEW.md), [prototype status](07_QA/06_PROTOTYPE_STATUS.md), [QA/release gate](07_QA/04_QA_AND_RELEASE.md).
7. [Resume log template](00_Project_Brief/03_PRODUCTION_LOG_TEMPLATE.md).

## Current honest status
A simple, silent 60-second animated **prototype** was created for checking motion and scene timing. It does **not** use the approved cinematic infographic or moving spatial 3D mind-map design, contains no verified natural voice and is NOT the final video. It must be rebuilt with the approved art. The final 1080x1920 MP4 has not been rendered or uploaded.

## Reference folder layout
```text
Digital Videos/
  AI Video Creation/
    00_Project_Brief/      reusable prompt and plan
    01_References/         approved reference art [not yet uploaded]
    02_Scripts/            draft narration and shots
    03_Storyboards/        scene review images [not yet uploaded]
    04_Assets/             editable asset and motion specifications
    05_Animation/          prototype renderer
    06_Audio/              voice/music/SFX [not yet produced]
    07_QA/                 checks and review log
    08_Exports/            final/prototype videos [not uploaded]
```

Git does not track empty directories. GitHub stores the existing documentation/code now; image references, Word binary, the local prototype MP4 and final video must be separately uploaded once rights and final render gates are satisfied. The editable Markdown master prompt **is already version-controlled in GitHub**; a downloadable editable Word template is also available in the conversation.

## Re-run prototype on Windows
Install Python and FFmpeg; open PowerShell in `05_Animation`:

```powershell
py -m pip install -r requirements.txt
py render_animatic.py --output motion_preview.mp4
```

**Do not claim this prototype matches approved visuals.** Replace every primitive stand-in with approved layered art / scene geometry, actually animate flows and branches, record and time natural narration, then evaluate a phone-sized video before release.
