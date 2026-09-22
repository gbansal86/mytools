# Technical notes

## Detection method

The scanner does **not** compare normal MD5/SHA file hashes. Those hashes change whenever a video is re-encoded.

Instead it:

1. Reads duration and video dimensions with FFprobe.
2. Samples 11 positions across each video.
3. Converts each sample frame to a tiny 9×8 grayscale image.
4. Calculates a 64-bit difference hash (dHash).
5. Compares Hamming distances between hashes.
6. For promising candidates, rechecks each sample against nearby timestamps (`-10`, `-5`, `0`, `+5`, `+10` seconds).
7. Reports pairs whose matched-sample ratio passes the configured threshold.

## Why a cache exists

`video_fingerprint_cache.json` stores fingerprints together with file size and modification time. Unchanged files can be reused on the next run rather than decoded again.

## Grouping caveat

Duplicate groups are built transitively. If A matches B and B matches C, all three can appear in one group even if A and C were not directly compared as a strong pair. The CSV report is therefore the detailed source for pair-by-pair evidence.

## Browser review server

The review UI binds only to `127.0.0.1` (localhost). It streams local media with HTTP byte-range support so seeking works in browsers that support the file's codec/container.

## Deletion safety

`review_duplicates.py` moves selected files to the Windows Recycle Bin using `SHFileOperationW` with `FOF_ALLOWUNDO`. It also blocks any request that would select all remaining files in a duplicate group.

## Limitations

- Browser playback depends on browser codec support. MP4/H.264 is usually safest.
- Visual hashing can miss heavily cropped, mirrored, overlaid, sped-up, or substantially edited copies.
- Audio fingerprinting is not implemented in this release.
- The suggested keeper is based on resolution, duration, and size. It is not a guarantee of perceptual quality.
