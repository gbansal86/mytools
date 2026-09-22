# Technical Notes

## Architecture

The tool has three deliberately separate stages:

1. **Setup** — installs a private Python environment and Nuditag under E:\Nuditag.
2. **Scan/report** — filters paths, scores videos, and writes CSV only.
3. **Optional move** — reads the reviewed NSFW CSV and moves files only after a dry run and explicit confirmation.

Keeping stage 3 separate is intentional: classification should not automatically become a filesystem action.

## Upstream version pin

The setup currently installs Nuditag from this upstream commit:

~~~text
f34134341b62cb320ac299e60335d432f19d6ebf
~~~

Repository:

https://github.com/ICIJ/nuditag

The wrapper uses Nuditag's internal Python APIs:

~~~python
from nuditag.media import MediaKind, VIDEO_EXTENSIONS
from nuditag.pool import default_worker_count, media_scorer
~~~

Pinning the source revision makes that integration reproducible. If the upstream internal API changes, review and test nuditag_custom_scan.py before changing the pin.

## Why not just call nuditag scan E:\ ?

The upstream CLI already supports a recursive target directory, threshold, frame count, workers, extension filters, resume, and NSFW-only output.

This wrapper adds:

- multiple independent roots;
- a separate exclusion list;
- pruning exclusions before files reach the scorer;
- videos-only discovery;
- de-duplication of overlapping search roots;
- synchronization of old report rows with current include/exclude rules.

## Report schema

The wrapper intentionally writes the same four columns used by Nuditag CSV reports:

~~~text
path,media_type,tag,score
~~~

Example:

~~~csv
path,media_type,tag,score
E:\Videos\clip.mp4,video,nsfw,0.8123
~~~

## Threshold logic

The wrapper uses:

~~~python
tag = "nsfw" if score >= threshold else "sfw"
~~~

The default threshold is 0.40.

Changing only the threshold re-tags retained scores without re-decoding or re-scoring the file.

## How Nuditag scores a video

At the pinned upstream revision, Nuditag samples frames across the video and scores frames with its local ONNX classifier.

For video aggregation, Nuditag uses the **second-highest sampled-frame score** when more than one frame decoded. This reduces the chance that one unusual or misclassified frame alone flags the entire video.

The wrapper defaults to requesting 32 sampled positions per video. Nuditag itself controls decoding and final score aggregation.

## Local model/cache

The wrapper sets:

~~~text
HF_HOME=E:\Nuditag\ModelCache
HF_HUB_CACHE=E:\Nuditag\ModelCache\hub
XDG_CACHE_HOME=E:\Nuditag\Cache
TEMP=E:\Nuditag\Temp
TMP=E:\Nuditag\Temp
~~~

At the pinned upstream revision, Nuditag's classifier references:

~~~text
ICIJ/nsfw-image-detection-384-onnx
~~~

and verifies the expected model SHA-256 before scoring.

## Resume/checkpoint strategy

ALL_FULL_REPORT.csv is the checkpoint.

Before scoring:

1. current candidate videos are discovered from SearchPaths and ExcludePaths;
2. valid existing rows are read;
3. rows whose paths no longer belong to the current candidate set are dropped;
4. retained scores are re-tagged using the current threshold;
5. only unseen paths are sent to the scorer.

During scoring each successful row is written and flushed immediately.

## Important resume limitation

Path is the resume identity.

If a file is renamed or moved, it appears as a new path and is scored again. The previous path drops out when it is no longer a current candidate.

The wrapper does not hash full video contents for identity because that would add substantial I/O to a large library scan.

## Exclusion semantics

Path comparisons use normalized absolute paths and Python's common-path logic.

Therefore excluding E:\Private excludes both E:\Private and everything below it.

Different drive letters are safely treated as unrelated.

## Symlinks and junctions

The walker does not follow symlinks. On Python versions that expose Windows junction detection, junctions are also skipped.

This prevents recursive loops and unexpected traversal into another filesystem tree.

## File mover safety

Move_NSFW_From_Report.ps1 uses PowerShell LiteralPath handling to avoid wildcard interpretation.

Before each move it:

1. confirms the source still exists;
2. skips files already directly inside a folder named NSFW;
3. creates the destination folder if necessary;
4. chooses a unique destination filename rather than overwrite;
5. logs success or failure.

The BAT runs the PowerShell helper once in dry-run mode, then requires the user to type MOVE before invoking the real move.

## Filesystem side effects

The scanner reads videos and writes only report/cache/runtime data under E:\Nuditag.

The mover changes video locations only after explicit user confirmation.

No delete operation exists in this wrapper.
