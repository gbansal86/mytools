# Governance

MyTools currently uses a **maintainer-led** governance model.

## Decision making

Routine bug fixes, documentation changes, tests, and compatible improvements are reviewed through pull requests. Larger changes should begin with an issue so scope, safety, dependencies, compatibility, and testing can be discussed before implementation.

Technical decisions prioritize, in order:

1. protecting user data and credentials;
2. correctness and reproducibility;
3. understandable behavior for non-specialist users;
4. maintainability and dependency quality;
5. performance and convenience.

The primary maintainer makes the final merge/release decision when trade-offs remain unresolved.

## Changes requiring extra review

The following deserve explicit review and testing:

- destructive file operations;
- administrator/elevated Windows changes;
- credential/session handling;
- externally downloaded executables or models;
- new network services or APIs;
- dependency changes with licensing/security implications;
- backward-incompatible configuration or report formats.

## Releases

Releases must represent real tested changes. Backdated, empty, or cosmetic releases intended only to create an appearance of project maturity are not part of this project's governance model. See [RELEASING.md](./RELEASING.md).

## Security

Security-sensitive reports follow [SECURITY.md](./SECURITY.md). Public issues should never contain credentials, private sessions, personal data, or exploit details that would create unnecessary risk.

## Community participation

Contributors may propose changes, review pull requests, report bugs, improve documentation, and suggest roadmap items. Sustained contributors may be considered for maintainer responsibilities as described in [MAINTAINERS.md](./MAINTAINERS.md).
