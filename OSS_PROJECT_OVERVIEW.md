# Open-Source Project Overview

## What MyTools is

MyTools is a public, MIT-licensed collection of practical Windows utilities maintained in one repository. The tools focus on local diagnostics, media/file organization, duplicate detection, archive handling, USB inspection, emulator repair, Telegram-local archival workflows, and small-scale local LLM infrastructure.

The common theme is making technically awkward tasks usable by people who may not be comfortable assembling command-line dependencies, interpreting low-level Windows information, or designing safe review workflows themselves.

## Why a multi-tool repository

The utilities solve different problems but share Windows-first setup/troubleshooting, beginner-facing documentation, safe handling of local files, dependency validation, privacy/credential hygiene, reporting/visual guidance, and conservative behavior around destructive actions.

## Design philosophy

- **Human-readable operation:** explain what the tool is doing, required inputs, output location, and failure recovery.
- **Safety as functionality:** separate scanning/review from destructive actions and preserve previews/dry runs where practical.
- **Local-first processing:** keep source data local unless the function genuinely requires a network service.
- **Transparent dependencies:** name FFmpeg, ADB, Nuditag, Python packages, llama.cpp-related components, and other dependencies rather than hiding them.
- **Source-first distribution:** favor readable source, scripts, examples, and documentation.

## Current tool families

**File and media maintenance:** Book Duplicate Finder, Video Duplicate Finder, Nuditag NSFW Video Scanner, Nested Archive Extractor, ZIP Bulk Extractor.

**Windows diagnostics and repair:** Windows PC Performance & Hardware Health Recovery, USB Port Explorer Pro, LDPlayer Firebase #303 / Internet Repair.

**Data and infrastructure workflows:** Telegram Local Downloader for Windows and 3-PC LLM Cluster guide/helpers.

## Maintenance model

The repository is maintainer-led, with public issues and pull requests available for outside participation. Maintenance responsibilities include reviewing changes, reproducing bugs, protecting privacy/credential boundaries, updating documentation as dependencies change, keeping validation healthy, documenting safety-sensitive behavior, preparing releases, and tracking compatibility limitations.

External contributions are welcome under [CONTRIBUTING.md](./CONTRIBUTING.md).

## Testing and maintenance evidence

Repository CI performs Python compilation, PowerShell parsing, repository-structure validation, and documentation-link integrity checks. CodeQL analyzes supported Python source. A separate dependency-security workflow audits the maintained Python requirement manifests and produces JSON evidence plus CycloneDX SBOMs.

The repository also uses Dependabot, CODEOWNERS, issue/PR templates, maintainer/governance documentation, public pull requests, and per-tool annotated guides. Tool-specific testing is documented in [TESTING.md](./TESTING.md). Hardware, emulator, Telegram, and Windows repair workflows also require controlled manual testing.

## Security and privacy model

Session files, credentials, tokens, personal reports, caches, and private content should remain outside version control. Sensitive vulnerability handling is documented in [SECURITY.md](./SECURITY.md), with repository-wide trust boundaries documented in [THREAT_MODEL.md](./THREAT_MODEL.md).

## Release policy

The project will use real, versioned releases as tools stabilize. Releases should be tied to tested code and honest release notes; the project avoids backdated or empty releases intended only to create an appearance of maturity.

## Current project scope

The repository currently contains 11 independently usable Windows-focused utilities across file/media maintenance, diagnostics/repair, local data workflows, and local LLM infrastructure. The tools include extensive beginner-oriented documentation and dozens of annotated diagrams and workflow images. See [TOOL_GALLERY.md](./TOOL_GALLERY.md).

## Adoption and ecosystem evidence

Repository popularity metrics should be reported exactly as GitHub shows them. The project does not claim adoption that has not occurred.

As the project grows, meaningful evidence can include genuine stars/forks, independent issue reports, external pull requests, release downloads, references from other documentation/repositories, recurring compatibility requests, and documented third-party use cases.

The goal is to earn those signals through useful maintenance rather than manufacture them.

## Roadmap

The current roadmap prioritizes release discipline, test coverage, safe shared patterns, compatibility documentation, and contributor onboarding. See [ROADMAP.md](./ROADMAP.md).
