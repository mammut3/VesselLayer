# Contributing to VesselLayer

VesselLayer welcomes focused contributions that preserve its transport-neutral, vendor-neutral boundary.

## Before contributing

- Read the README, architecture, glossary, and conformance principles.
- Keep protocol, transport, vendor, application, and UI concerns behind adapters or outside this repository.
- Open an issue or discussion before proposing a broad vocabulary or boundary expansion.
- Explain the user or interoperability problem and the evidence supporting the change.

## AI-assisted contributions

AI assistance is welcome. Contributors remain responsible for everything they submit, including correctness, security, provenance, licensing, tests, and documentation.

- Do not submit generated code or text whose source or license is uncertain.
- Do not use AI to disguise copying from proprietary standards, incompatible licenses, source-available projects, or unlicensed repositories.
- Identify important external sources and prior art when they materially influenced a contribution.
- Review generated material with the same rigor as human-written material.
- Marine and control-related changes require appropriate standards, fixture, bench, simulator, or vessel evidence; generated reasoning alone is insufficient.
- Behavioral changes require technology-neutral examples or conformance evidence appropriate to their risk.

## Provenance and licensing

Contributions should distinguish:

1. original VesselLayer work;
2. standards-derived concepts described without redistributing restricted text;
3. open-source prior art or adapted concepts, with project, version/commit, license, and relevant source identified; and
4. dependency code actually incorporated, if any, with license/NOTICE obligations satisfied.

Do not copy proprietary NMEA specification text or definitions into VesselLayer. Do not claim NMEA certification. GPL, source-available, or unlicensed implementation code must not be copied into this Apache-2.0 repository. Interoperability observations and independently expressed concepts may be documented only when their provenance and legal basis are clear.

## Change quality

- Keep contracts small and application-neutral.
- Preserve deterministic behavior and controlled-time testability.
- Do not infer authority from provider registration or arrival order.
- Keep qualification evidence separate from authorization and current availability.
- Represent unsupported, rejected, timed-out, cancelled, and uncertain command outcomes honestly.
- Avoid speculative modules, services, and dependencies.

Accepted changes are reviewed and approved by human maintainers, who remain accountable for the project.
