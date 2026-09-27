# Fixture Policy

VesselLayer conformance work distinguishes three evidence classes:

1. **Synthetic/public fixtures** — designed scenarios containing no vessel or owner data; preferred for public conformance vectors.
2. **Sanitized vessel-derived fixtures** — derived from real evidence with locations, stable device identifiers, owner information, and other sensitive data removed or transformed while preserving relevant behavior.
3. **Restricted/raw vessel evidence** — lossless source captures retained privately with access controls, provenance, timing, direction, gateway/firmware, configuration, and transformation records.

Raw or identifying vessel evidence must not be committed to this public repository. In particular, do not publish Sunrise captures, fishing locations, stable equipment identifiers, credentials, or proprietary standards material.

Every derived fixture should record its provenance category, transformation method, applicable contract/specification version, and expected semantic result. Sanitized fixtures supplement rather than replace restricted raw evidence.

The vectors under `conformance/0.1.0` are original synthetic/public scenarios.
They exercise the initial provider lifecycle, controlled time, freshness, and
deterministic read-authority contract and contain no vessel-derived data.
