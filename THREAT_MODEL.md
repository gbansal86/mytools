# MyTools Threat Model

MyTools is a collection of local-first Windows utilities. The tools are independent, but they share important security boundaries because they inspect real files, invoke command-line programs, sometimes require elevation, and in a few cases communicate with external services.

This document describes the repository-wide model. Tool-specific documentation can impose stricter rules.

## Assets to protect

- User documents, books, videos, course libraries, archives, and diagnostic data.
- Windows configuration and system state.
- Telegram API credentials, session files, authentication state, and private channel data.
- Local paths, usernames, host-specific diagnostic exports, logs, and reports.
- Integrity of downloaded third-party tools and Python dependencies.
- The public GitHub repository and release/source artifacts.

## Trust boundaries

### Local filesystem

Many utilities enumerate, hash, inspect, copy, move, rename, extract, or organize files.

Primary risks include path traversal, archive traversal, accidental overwrite, symlink/reparse-point surprises, unsafe deletion, processing an unintended root, and exposing private paths in reports.

Preferred controls are preview/dry-run modes, explicit source/destination configuration, confirmation before destructive actions, Recycle Bin workflows where practical, and clear output/report locations.

### Elevated Windows operations

Diagnostics and repair utilities can require administrator privileges.

Primary risks include unintended registry/service/network changes and running a broad operation with more privilege than required.

Preferred controls are read-only diagnostics first, explicit elevation, clear separation between scan and repair, documented rollback/recovery paths, and narrow command scopes.

### Subprocesses and external binaries

Several tools invoke PowerShell, Python, FFmpeg/FFprobe, ADB, archive utilities, or other programs.

Primary risks include command/argument injection, unsafe shell interpolation, dependency substitution, untrusted executable discovery on PATH, and unexpected behavior from third-party binaries.

Preferred controls are argument-safe process invocation, validation of user-supplied paths, documented dependencies, avoiding unnecessary shell evaluation, and recording dependency/version expectations.

### Archive extraction

Nested Archive Extractor and related workflows handle attacker-controlled filenames and nested content.

Primary risks include Zip Slip/path traversal, decompression bombs, extension spoofing, overwrite collisions, and recursive extraction loops.

Extraction logic should keep outputs inside the intended destination, bound recursion/work where practical, and avoid silently overwriting unrelated files.

### Local web/report interfaces

Some tools create HTML reports or browser-based review interfaces.

Primary risks include unescaped filenames/metadata becoming HTML or script injection, localhost interfaces being reachable more broadly than intended, and destructive operations being triggered without clear confirmation.

Generated HTML should escape untrusted text. Local services should bind only as broadly as required and should keep file-changing actions explicit and reviewable.

### Telegram and other network services

Telegram Local Downloader uses credentials supplied by the user and accesses content available to that signed-in account.

Primary risks include credential/session leakage, accidentally publishing private content, excessive permissions, and committing generated session/runtime data.

Credentials and sessions must remain outside version control. Examples must be synthetic or sanitized. Network-backed tools should make authorization boundaries clear.

### Dependency and supply chain

Python packages, GitHub Actions, FFmpeg, ADB, Nuditag, llama.cpp-related components, and other third-party software introduce supply-chain risk.

The repository uses Dependabot, CodeQL for supported source analysis, dependency auditing, and CycloneDX SBOM generation for Python requirement manifests. Third-party licenses and provenance remain the responsibility of their respective projects.

## AI and generated-code review

AI-assisted development can accelerate maintenance, but generated changes are not trusted by default. Security-sensitive changes should remain reviewable, preserve tests/validation, avoid adding secrets or private fixtures, and document new network, filesystem, privilege, or dependency boundaries.

## Public-repository boundary

The public repository must not contain live credentials, Telegram sessions, personal diagnostic exports, private media, browser cookies, machine-specific secrets, or private file inventories.

Deleting a secret from the latest tree does not remove it from Git history. Exposed secrets should be revoked/rotated, and history should be rewritten when appropriate.

## Security review checklist

For a meaningful change, ask:

1. Does it expand filesystem write/delete/move behavior?
2. Does it introduce or change an elevated operation?
3. Does it construct a shell command from user-controlled text?
4. Does it extract archives or trust filenames from external sources?
5. Does it expose local data through HTML, localhost, logs, or network APIs?
6. Does it add a credential, token, session, cookie, or authentication flow?
7. Does it add or materially change a third-party dependency?
8. Can the behavior be previewed, tested with synthetic fixtures, or rolled back?
9. Are private paths/data excluded from examples, tests, screenshots, and commits?
10. Are documentation and validation updated with the change?

See [SECURITY.md](./SECURITY.md) for vulnerability reporting.
