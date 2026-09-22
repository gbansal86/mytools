# Contributing to MyTools

Thank you for considering a contribution. MyTools is a collection of practical Windows-focused utilities, so contributions should prioritize safety, clarity, reproducibility, and usefulness for non-specialist users.

## Good contributions

Useful contributions include confirmed bug fixes, safer error handling and rollback behavior, tests and validation, documentation corrections, clearer beginner instructions or diagrams, compatibility improvements, performance improvements with measurable benefit, and small new utilities that fit the repository's practical-tool scope.

## Before making a large change

For a substantial feature, behavior change, dependency change, or new tool, open an issue first. Explain the problem, intended users, proposed approach, safety implications, dependencies, and how you plan to test it.

Small typo/documentation fixes can go directly to a pull request.

## Development rules

1. Keep changes scoped to one purpose.
2. Do not commit credentials, API IDs/hashes, session files, tokens, private reports, personal paths, generated caches, or copyrighted sample content that cannot be redistributed.
3. Prefer standard-library or well-maintained dependencies.
4. Document every new external dependency and its purpose.
5. Preserve dry-run/read-only behavior where it already exists.
6. Do not make destructive actions automatic merely for convenience.
7. Keep beginner-facing messages understandable and actionable.
8. Add or update documentation when behavior changes.
9. Respect third-party licenses and attribution requirements.

## Testing

Before opening a pull request, run the relevant tool on representative test data where safe, run syntax checks for changed source files, verify that no machine-specific paths or secrets were introduced, test failure paths, and document manual testing in the pull request.

See [TESTING.md](./TESTING.md) for repository-level checks.

## Pull requests

A good pull request should include the problem, affected tool, changes, safety/compatibility implications, testing performed, screenshots/sample output when useful, and known limitations.

Keep unrelated refactors out of a functional change unless required.

## New tool checklist

A new top-level tool should normally include a descriptive folder name, `README.md`, `LICENSE`, quick-start instructions, prerequisites, safety/permissions notes, troubleshooting, source code rather than only packaged binaries, suitable ignore rules for runtime data, and test/self-check instructions where practical.

## Code style

There is no single language requirement. Match the existing style of the tool you are changing.

For Python, favor clear modules, explicit error messages, `pathlib` where practical, and type hints for non-trivial interfaces.

For PowerShell, use descriptive function/variable names, explicit error handling, and avoid unnecessary elevation.

For BAT files, keep complex logic in Python or PowerShell when doing so improves safety and maintainability.

## License

By contributing, you agree that your contribution may be distributed under the repository's MIT License. Do not submit code you do not have the right to contribute.
