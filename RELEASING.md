# Release Policy

MyTools is a multi-tool repository. Releases should be understandable to users who care about only one utility.

## Versioning

Use semantic-style versions (`MAJOR.MINOR.PATCH`) where practical:

- **PATCH** — fixes, documentation corrections, non-breaking hardening;
- **MINOR** — backward-compatible functionality;
- **MAJOR** — incompatible behavior, data format, CLI, or workflow changes.

A repository release may contain changes for one or several tools. Release notes must clearly name the affected tools.

## Release checklist

Before publishing a release:

1. confirm repository validation is green;
2. run the affected tool's documented manual/functional tests;
3. update relevant changelogs/version files;
4. review new dependencies and license/attribution obligations;
5. review ignore rules and packaged files for secrets/runtime artifacts;
6. check installation and quick-start instructions;
7. document breaking changes, migrations, rollback options, and known limitations;
8. create a signed or annotated tag when practical;
9. publish GitHub release notes with testing evidence;
10. verify source archives contain expected documentation and licenses.

## Release note template

Include version/date, affected tools, highlights, fixes, safety/security changes, dependency changes, testing performed, known limitations, and upgrade/rollback notes where applicable.

## No artificial release history

Do not backdate releases or create empty releases to make the project appear older or more active. Release history should reflect real maintained versions.
