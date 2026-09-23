# MyTools

[![Repository validation](https://github.com/gbansal86/mytools/actions/workflows/validate.yml/badge.svg)](https://github.com/gbansal86/mytools/actions/workflows/validate.yml)
[![CodeQL](https://github.com/gbansal86/mytools/actions/workflows/codeql.yml/badge.svg)](https://github.com/gbansal86/mytools/actions/workflows/codeql.yml)
[![Dependency Security](https://github.com/gbansal86/mytools/actions/workflows/dependency-security.yml/badge.svg)](https://github.com/gbansal86/mytools/actions/workflows/dependency-security.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

**MyTools** is an open-source collection of practical Windows utilities for diagnostics, local data management, media/file maintenance, automation, and technical workflows that are often difficult for non-specialist users to perform safely.

The repository intentionally keeps related small utilities together so they can share documentation standards, safety practices, contribution rules, validation, and maintenance processes while remaining independently usable from their own folders.

## Project goals

MyTools is built around five principles:

1. **Useful before clever** — solve concrete desktop and local-data problems with understandable tools.
2. **Beginner-friendly operation** — provide quick starts, annotated guides, examples, and plain-English explanations.
3. **Safety by default** — prefer read-only inspection, dry runs, explicit confirmation, Recycle Bin workflows, or clearly documented destructive steps.
4. **Local-first where practical** — keep processing on the user's computer unless a tool explicitly requires an external service.
5. **Maintainable open source** — keep source, licensing, validation, security guidance, release practices, and contribution paths visible.

## Included tools

| Tool | What it does | Main technologies |
|---|---|---|
| [Book Duplicate Finder](./Book-Duplicate-Finder/) | Finds exact and near-duplicate books/documents across multiple formats and produces review reports. | Python, Windows |
| [Video Duplicate Finder](./Video-Duplicate-Finder/) | Detects re-encoded or near-duplicate videos using perceptual sampling and provides a browser review workflow. | Python, FFmpeg, Windows |
| [Windows PC Performance Recovery](./Windows-PC-Performance-Recovery/) | Collects diagnostics, analyzes performance/hardware-health signals, supports dry-run repairs, and compares before/after results. | PowerShell, BAT, Windows |
| [USB Port Explorer Pro](./USB-Port-Explorer-Pro/) | Explains USB topology, devices, drivers, ports, protocol clues, and practical speed/port guidance. | PowerShell, Windows |
| [Course Library Manager](./Course-Library-Manager/) | Cleans course-folder names and builds an offline HTML course library/player with Cards/Table views, subtitles, progress/resume, resources, and optional FFmpeg thumbnails. | PowerShell, HTML/JavaScript, FFmpeg, Windows |
| [Telegram Local Downloader](./Telegram-Local-Downloader-Windows/) | Downloads media the signed-in Telegram account can already access and creates organized local reports/archives. | Python, Telegram API, Windows |
| [Nuditag NSFW Video Scanner](./Nuditag-NSFW-Video-Scanner/) | Wraps Nuditag for configurable local video scanning with resumable reports and a dry-run-first organizer. | Python, Nuditag, Windows |
| [Nested Archive Extractor](./Nested-Archive-Extractor/) | Recursively extracts archives inside archives, including extensionless inner archives and Zstandard wrappers. | PowerShell, Windows |
| [ZIP Bulk Extractor](./ZIP-Bulk-Extractor/) | Extracts many ZIP files with beginner-oriented safe modes and no third-party dependency. | BAT, Windows |
| [3-PC LLM Cluster](./3-PC-LLM-Cluster/) | Documents and checks a small multi-PC setup for distributed/local LLM experimentation. | PowerShell, llama.cpp-oriented examples |
| [LDPlayer Firebase #303 / Internet Repair](./LDPlayer-Firebase-303-Repair/) | Diagnoses common LDPlayer ADB/network/Google-services issues related to connectivity and Firebase token failures. | BAT, ADB, Windows |
| [ChatGPT Plugin Catalog](./ChatGPT-Plugin-Catalog/) | Point-in-time research catalog of discoverable ChatGPT apps/connectors, their purpose, free-plan limits, connector eligibility, and visual tool galleries. | Excel research, Markdown, SVG |

Each tool folder is intended to be understandable on its own and contains its own README and MIT license.

For a visual tour of the utility collection, see the [MyTools Visual Gallery](./TOOL_GALLERY.md). The [ChatGPT Plugin Catalog](./ChatGPT-Plugin-Catalog/) includes its own four-part gallery covering all 92 apps in the 2026-09-23 snapshot.

## Safety model

The utilities operate on real local files and Windows configuration, so safety is treated as a feature rather than an afterthought.

- Scanners should not silently delete source data.
- Destructive or repair operations should be separated from discovery/review when practical.
- Dry-run or preview modes are preferred where a change can be risky.
- Credentials, Telegram sessions, generated reports, caches, and machine-specific artifacts should not be committed.
- External dependencies and third-party components should be identified and used under their own licenses.
- Users should read the tool-specific README before running scripts with administrator privileges.

See [SECURITY.md](./SECURITY.md), the repository-wide [Threat Model](./THREAT_MODEL.md), and the safety notes in each tool's documentation.

## Validation and testing

Repository validation runs through GitHub Actions on pushes and pull requests. The current baseline checks:

- Python source files compile successfully.
- PowerShell scripts parse without syntax errors.
- Required root community/maintenance files exist.
- Every top-level tool directory contains both a README and LICENSE.
- Local Markdown/image links are checked so documentation does not silently rot.
- CodeQL analyzes supported Python source on pushes, pull requests, and a weekly schedule.
- Python dependency manifests are audited with `pip-audit`; JSON audit evidence and CycloneDX SBOMs are retained as workflow artifacts.

These checks are intentionally dependency-light so contributors can get quick feedback. Tool-specific functional tests and manual validation remain important where scripts depend on Windows hardware, ADB, Telegram, FFmpeg, or other external programs.

See [TESTING.md](./TESTING.md).

## Contributing

Issues, documentation improvements, bug fixes, portability improvements, tests, and carefully scoped new utilities are welcome.

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before submitting a pull request. For support questions, see [SUPPORT.md](./SUPPORT.md). Security-sensitive reports should follow [SECURITY.md](./SECURITY.md).

## Governance, maintainers, and releases

MyTools currently uses a maintainer-led governance model. The current maintainer and responsibilities are documented in [MAINTAINERS.md](./MAINTAINERS.md), and decision-making rules are documented in [GOVERNANCE.md](./GOVERNANCE.md).

### Maintenance and releases

The repository uses a shared maintenance model while allowing each tool to evolve independently.

- Changes should be reviewable and scoped.
- User-visible changes should be documented.
- Release tags should use semantic-style versions where practical.
- Release notes should state the affected tool(s), major changes, testing performed, dependencies, and known limitations.
- Significant behavior changes should include migration or rollback notes when relevant.

See [RELEASING.md](./RELEASING.md), [CHANGELOG.md](./CHANGELOG.md), and [ROADMAP.md](./ROADMAP.md).

## Open-source project overview

For a concise explanation of the repository's scope, maintenance model, quality practices, safety approach, and ecosystem goals, see [OSS_PROJECT_OVERVIEW.md](./OSS_PROJECT_OVERVIEW.md).

## License

The repository is licensed under the [MIT License](./LICENSE). Individual tool folders also include MIT license files for clarity when a tool is downloaded or copied independently.

Third-party software, libraries, models, binaries, and services referenced by a tool remain subject to their own licenses and terms.
