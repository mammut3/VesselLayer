# Specification

This directory will hold normative, technology-neutral VesselLayer contracts and JSON Schema 2020-12 documents as concrete consumer validation justifies them.

JSON Schema is selected for serialized descriptors, evidence, fixture envelopes, and expected results. Behavioral rules remain normative prose plus conformance vectors. The pure-Swift reference API is idiomatic and is not generated wholesale from the schemas; future language implementations may generate transfer models where useful.

The schemas and public synthetic vectors under `fixtures/conformance/0.1.0` cover
read-only provider and asset lifecycle, controlled time, freshness, deterministic
read authority, provisional provider reconciliation/removal, transport-neutral
asset/provider matching, and capability state.
The architecture and conformance documents remain authoritative for behavior not captured
by JSON Schema.

## Observation projection ordering and coherent reads

For each observation/provider latest-value slot, an input with an older host
`receivedAt` must not replace the current candidate. Equal timestamps use arrival
order, including invalid observations. Reconciliation preserves the newer sample
when provisional and durable candidates collide. These rules preserve original
receipt times; completion of a multipart input is not a fresh receipt.

Authority, source-map rows and read capability each observe one coherent store
snapshot after their clock read. Eligibility, candidate value and provider lifecycle
must come from that snapshot; a removed provider's observation cannot be combined
with a newly registered provider generation. Registration tokens are opaque,
process-local cache ownership evidence and convey no command authority.
