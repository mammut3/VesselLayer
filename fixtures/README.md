# Fixture Policy

VesselLayer conformance work distinguishes three evidence classes:

1. **Synthetic/public fixtures** — designed scenarios containing no vessel or owner data; preferred for public conformance vectors.
2. **Sanitized vessel-derived fixtures** — derived from real evidence with locations, stable device identifiers, owner information, and other sensitive data removed or transformed while preserving relevant behavior.
3. **Restricted/raw vessel evidence** — lossless source captures retained privately with access controls, provenance, timing, direction, gateway/firmware, configuration, and transformation records.

Raw or identifying vessel evidence must not be committed to this public repository. In particular, do not publish Sunrise captures, fishing locations, stable equipment identifiers, credentials, or proprietary standards material.

Every derived fixture should record its provenance category, transformation method, applicable contract/specification version, and expected semantic result. Sanitized fixtures supplement rather than replace restricted raw evidence.

The vectors under `conformance/0.1.0` are original synthetic/public scenarios.
They exercise provider lifecycle, controlled time, freshness, deterministic
read authority, asset enrichment, disappearance/reappearance, and explicit
ambiguous/conflicting identity states. They contain no vessel-derived data.

`provider-registration-ownership.json` is original synthetic/public scheduling
conformance evidence. Its common schedule pauses the named operation before its
timestamp is returned, replaces the named registration, then completes the old
operation. `source` and `target` are generic provider identifiers. An absent target
is also captured ownership state. Each vector expects all provider states,
registration identities and observations to equal the snapshot immediately before
old completion. No particular concurrency runtime, clock implementation, transport,
application, device or vessel is required to reproduce that schedule. The Swift
reference tests execute these vectors with a held clock; the existing lifecycle
tests also retain normal terminal withdrawal and unchanged-registration behavior.
