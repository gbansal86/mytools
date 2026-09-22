# Changelog

## 1.0.0 - 2026-09-22

- Public GitHub-ready sanitized release.
- Removed private Telegram credentials, session data, real channel list, and historic download report from the distributable source.
- Added safe example configuration files and `.gitignore` protections.
- Added CSV formula-injection protection for generated reports.
- Added HTML escaping, restrictive Content Security Policy, and relative archive paths.
- Added pre-publication privacy scanner.
- Added beginner documentation, troubleshooting guide, numbered diagrams, and MIT license.\n- Split the public Python code into configuration, media/report, progress, and orchestration modules for easier review and maintenance.\n- Public credential handling no longer writes the API hash automatically; credentials are read from environment variables, a private settings file, or an interactive prompt.
