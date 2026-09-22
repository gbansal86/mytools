# Security Policy

## Scope

MyTools contains utilities that may inspect local files, call command-line programs, use administrator privileges, connect to Telegram through a user's own credentials, or change local Windows configuration. Security reports are therefore taken seriously even when a tool is intended only for local use.

## Supported code

Until formal versioned releases are published, the latest `main` branch is the supported source baseline. After releases begin, security fixes will normally target the latest release and `main`; older snapshots may not receive backports.

## Reporting a vulnerability

Please **do not publish credentials, tokens, Telegram API values, session files, private file paths, personal reports, or weaponized exploit details in a public issue**.

If GitHub Private Vulnerability Reporting is available for this repository, use it for sensitive reports. If it is not available, open a minimal public issue stating that you have a security concern and the affected tool, but omit secrets and exploit details so the maintainer can arrange a safer exchange.

For ordinary non-sensitive security hardening suggestions, a normal issue or pull request is appropriate.

## What to include

A useful report includes the affected tool/file/version/commit, Windows and dependency versions, clear reproduction steps using non-sensitive test data, expected versus actual behavior, practical impact, privilege requirements, and suggested mitigation if known.

## Credential and privacy rules

Never commit or attach `.env` files containing secrets, Telegram `.session` files or API credentials, private access tokens, personal diagnostic exports, private media/document samples, browser cookies, cloud credentials, or machine-specific secrets.

If a secret has already been committed, deleting the file in a later commit is not sufficient. Revoke/rotate the secret and remove it from Git history where appropriate.

## Dependency security

Third-party tools and libraries are maintained by their respective projects. Contributors should avoid unnecessary dependencies, constrain dependencies when appropriate, and document externally downloaded binaries or tools.

The repository uses Dependabot for supported dependency manifests and GitHub Actions, CodeQL for supported Python source analysis, and `pip-audit` plus CycloneDX SBOM generation for the maintained Python requirement files. Automated checks complement rather than replace human review.

## Threat model

Repository-wide assets, trust boundaries, attack surfaces, and review questions are documented in [THREAT_MODEL.md](./THREAT_MODEL.md).

## Safe operation

Before running a tool that changes files or system settings, read its README, use dry-run/preview mode when available, keep backups of important data, review generated actions before applying them, and understand whether administrator privileges are needed.
