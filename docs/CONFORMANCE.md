# Conformance Principles

VesselLayer conformance should be testable without selecting an implementation language or runtime. Normative behavior will be expressed through versioned, technology-neutral fixtures/vectors containing inputs, controlled time, policy, evidence, lifecycle events, and expected semantic results.

Conformance coverage includes public synthetic vectors for deterministic read
authority and asset lifecycle. Further vectors should include:

- provider registration and lifecycle;
- provisional-to-durable provider reconciliation and obsolete-provider removal;
- asset/provider matching from generic evidence;
- observation validity, freshness, quality, and provenance;
- deterministic source authority and stable tie-breaking;
- qualification, revocation, authorization separation, and availability;
- equivalent capabilities from multiple providers;
- command outcomes, cancellation, timeout, and uncertainty;
- provider disappearance and reappearance without command replay; and
- injected clocks and deterministic scheduling.

A conformance vector proves agreement with a specified contract; it does not certify marine equipment, a vessel installation, an adapter, or a control path as safe. In particular, a matched provider or an observed control-like asset remains potential or unqualified unless separately scoped evidence, authorization, and live prerequisites make an operation available.

JSON Schema 2020-12 is the selected serialized format for conformance inputs and expected results. `conformance-vector.schema.json` describes read-authority vectors; `read-model.schema.json` describes the transport-neutral asset, provider-match, and capability records; and `read-model-conformance-vector.schema.json` describes asset-lifecycle vectors. The Swift reference tests execute the public vectors under `fixtures/conformance/0.1.0` with controlled time.
