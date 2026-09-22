# Testing and Validation

MyTools contains several independent Windows utilities, so testing is layered rather than forced into one framework.

## Automated repository checks

The GitHub Actions workflow at `.github/workflows/validate.yml` runs on pushes and pull requests and performs dependency-light checks on Windows:

1. Python files are compiled with `python -m py_compile`.
2. PowerShell `.ps1` and `.psm1` files are parsed using the PowerShell language parser.
3. Required root governance/maintenance files are checked.
4. Each top-level tool directory is checked for `README.md` and `LICENSE`.
5. Local Markdown/image links are checked across the repository.
6. The root README catalog is checked against the actual top-level tool folders.

The repository also runs CodeQL for supported Python source and a scheduled dependency-security workflow. The dependency workflow audits the maintained Python requirement manifests with `pip-audit`, uploads JSON audit evidence, and produces CycloneDX JSON SBOMs.

These checks catch common packaging, syntax, documentation, static-analysis, and dependency problems without running tools against a contributor's real files or machine configuration.

## Tool-level testing

File scanners and duplicate finders should use temporary fixtures containing known duplicates, near-duplicates, unrelated controls, corrupt files, and excluded directories. Confirm scanning does not modify source data unless a separate explicit action is invoked.

Windows diagnostics/repair tools should favor read-only and dry-run modes. Elevation-required actions should be tested on a disposable test machine or VM before broad use.

Telegram utilities should use a dedicated test account/channel where possible. Never commit API values or session files.

FFmpeg/media tools should use short synthetic or freely redistributable fixtures and record the FFmpeg version used.

ADB/LDPlayer tools should be tested against a disposable emulator instance and document LDPlayer/ADB versions.

## Pull request evidence

A pull request should describe automated checks, manual scenarios, operating system/dependency versions, expected/observed results, and untested scenarios.

Screenshots are useful for UI/report changes but should not reveal personal files, usernames, tokens, or private paths.

## Future improvements

Planned improvements include per-tool fixture suites, more unit tests around parsers/planners, and release smoke tests for the highest-use utilities.
