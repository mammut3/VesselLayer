# Codex Guidance — VesselLayer

## Project boundary

VesselLayer is a public, vendor-neutral, transport-neutral capability framework for marine applications. Preserve the technology-neutral specification, glossary, JSON Schema/conformance artifacts, and deterministic behavioral semantics as the cross-language authority. The pure-Swift package is the initial reference implementation, not permission to make Apple APIs or HelmBrain product behavior part of the framework.

Do not add marine transports, PGNs/codecs, NMEA discovery, Signal K runtime types, gateway drivers, databases, UI, cloud/plugin hosts, workflow engines, fishing features, or application policy to core. Keep qualification evidence separate from authorization and current availability; never infer control authority from discovery, provider matching, registration order, or successful byte transmission.

VesselLayer is Apache-2.0 licensed and intentionally AI-assisted. Preserve the public AI-assisted-development disclosure and explicit human accountability in `README.md` and `CONTRIBUTING.md`.

## Provenance and licensing

Follow `CONTRIBUTING.md` before incorporating external material. AI assistance does not change contributor responsibility for correctness, provenance, licensing, security, tests, or evidence.

- Do not copy proprietary NMEA specifications or claim NMEA certification.
- Do not copy GPL, source-available, or unlicensed implementation code into this permissively licensed repository without an explicit compatible licensing decision.
- A public repository is not permission to copy material without compatible terms.
- For incorporated code, data, schemas, mappings, or fixtures, record the exact upstream project, version/tag/commit, source path, verified license, modification status, attribution/NOTICE duties, and compatibility decision.
- Distinguish direct dependencies, generated derivatives, adapted artifacts, and conceptual/reference-only prior art. Cite conceptual influence without implying code incorporation.
- Recheck license and version at the time material enters the repository; do not rely solely on older research.
- Preserve provenance in generated files and machine-readable manifests. Prefer deterministic generation without volatile timestamps.
- Behavioral changes require technology-neutral conformance evidence. Marine/control claims require standards, fixture, simulator, bench, or vessel evidence appropriate to their risk; generated reasoning alone is insufficient.

## Git workflow and persistence

Before changing the repository, inspect the branch/worktree and local changes, fetch the configured remote, inspect remote `main`, and preserve existing work before reconciling any divergence. Do not start from a stale branch, overwrite newer remote work, force-push shared history, or discard unpublished work for convenience.

Meaningful changes must be validated, committed with a reviewable message, pushed to the configured GitHub remote, and verified by exact commit SHA. Direct updates to `main` or a task branch/PR are both acceptable when appropriate; do not create process-only PRs, and do not merge through unresolved validation failures, conflicts, or architecture decisions.

> **A repository-changing task is not complete until the completed commit is visible on remote GitHub, unless the preserved local-only result and exact persistence blocker are explicitly reported.**

Completion reports state the repository, branch, full commit SHA/message, changed files, validation, push/remote-verification status, PR if any, unresolved work, and whether `main` changed.

Final workflow:

> **sync → work → validate → commit → push → remotely verify → report → stop**

Do not continue into another backlog item or implementation tranche without explicit authorization.
