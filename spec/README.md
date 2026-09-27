# Specification

This directory will hold normative, technology-neutral VesselLayer contracts and JSON Schema 2020-12 documents as concrete consumer validation justifies them.

JSON Schema is selected for serialized descriptors, evidence, fixture envelopes, and expected results. Behavioral rules remain normative prose plus conformance vectors. The pure-Swift reference API is idiomatic and is not generated wholesale from the schemas; future language implementations may generate transfer models where useful.

The schemas and public synthetic vectors under `fixtures/conformance/0.1.0` cover
read-only provider and asset lifecycle, controlled time, freshness, deterministic
read authority, provisional provider reconciliation/removal, transport-neutral
asset/provider matching, and capability state.
The architecture and conformance documents remain authoritative for behavior not captured
by JSON Schema.
