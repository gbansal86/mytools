# Changelog

This file records repository-level changes. Individual tools may also maintain their own changelogs.

## 2026-09-22

### Repository foundation

- Published the initial multi-tool collection.
- Added MIT licenses to individual tool folders and the repository root.
- Expanded the root README with project scope, design principles, safety, validation, contribution, maintenance, and release information.
- Added contribution, security, support, testing, release, conduct, roadmap, and OSS project-overview documents.
- Added GitHub issue forms and a pull-request template.
- Added CODEOWNERS.
- Added repository-wide GitHub Actions validation for Python syntax, PowerShell syntax, required community files, and per-tool README/license presence.
- Added root ignore rules for common secrets, runtime state, caches, and generated local artifacts.
- Added explicit maintainer and governance documentation.
- Added weekly Dependabot checks for the two Python dependency manifests and GitHub Actions.
- Added CodeQL analysis for supported Python source.
- Added scheduled Python dependency audits with JSON evidence and CycloneDX SBOM artifacts.
- Added repository-wide threat-model documentation and documentation-integrity validation.
- Added a visual gallery linking annotated guides across all current utilities.
- Updated GitHub Actions checkout/setup-python usage to the current maintained major versions.

### Course Library Manager

- Added Course Library Manager v1.5.0 with preview-first folder cleanup and an offline HTML course library/player.
- Added annotated visual guides, a five-step quick start, an application infographic, architecture/troubleshooting/testing documentation, checksums, security guidance, third-party notices, and a per-tool MIT license.
- Documented optional locally installed FFmpeg/ffprobe support, subtitle conversion, browser progress/resume state, privacy behavior, and generated-output boundaries.

Future entries should describe real changes when they happen; do not backfill artificial history.
