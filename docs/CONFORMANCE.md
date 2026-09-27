# Conformance Principles

VesselLayer conformance should be testable without selecting an implementation language or runtime. Normative behavior will be expressed through versioned, technology-neutral fixtures/vectors containing inputs, controlled time, policy, evidence, lifecycle events, and expected semantic results.

Future conformance coverage should include:

- provider registration and lifecycle;
- asset/provider matching from generic evidence;
- observation validity, freshness, quality, and provenance;
- deterministic source authority and stable tie-breaking;
- qualification, revocation, authorization separation, and availability;
- equivalent capabilities from multiple providers;
- command outcomes, cancellation, timeout, and uncertainty;
- provider disappearance and reappearance without command replay; and
- injected clocks and deterministic scheduling.

A conformance vector proves agreement with a specified contract; it does not certify marine equipment, a vessel installation, an adapter, or a control path as safe.

This bootstrap defines principles only. It does not select a schema format or build a test runner.
