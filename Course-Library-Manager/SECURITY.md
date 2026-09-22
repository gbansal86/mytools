# Security and Privacy

Course Library Manager processes local folders and writes generated catalog data locally. It does not include telemetry or a remote catalog service.

The optional FFmpeg installer makes outbound HTTPS requests to public third-party build providers. Disable media thumbnail/duration options if you do not want those downloads.

Do not commit private settings, generated course inventories, `_CourseLibrary` output from private collections, rename reports/undo logs containing private paths, or downloaded third-party binaries without reviewing their licenses. The supplied `.gitignore` excludes these normal runtime artifacts.

For vulnerabilities, follow the repository-level [`SECURITY.md`](../SECURITY.md) rather than posting sensitive details publicly.
