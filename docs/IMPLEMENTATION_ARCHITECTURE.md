# Initial Implementation Architecture

- **Status:** Accepted
- **Decision date:** 2026-09-26

## Decision

VesselLayer will begin as a **technology-neutral specification plus a pure-Swift reference implementation** distributed with Swift Package Manager.

The cross-language contract is the semantic specification, stable identifiers, JSON Schema 2020-12 documents for serialized descriptors/evidence/fixtures, and language-neutral conformance vectors. The Swift API is an implementation of that contract, not the normative contract for every language.

HelmBrain is the first consumer and proves the Swift implementation, but the package must remain independently usable and contain no HelmBrain product behavior.

## Initial package boundary

The current read-only implementation includes only:

- a `VesselLayer` library target containing identifiers, typed observations, transport-neutral asset descriptors and in-memory lifecycle, provider descriptors/lifecycle and asset relationships, explicit provider-match evidence, validity/freshness/quality, source-map snapshots, capability availability, qualification/evidence values, deterministic read-source authority, and an injectable clock;
- a `VesselLayerTesting` target containing a manual clock, test providers, conformance-vector loading, and reusable assertions; and
- versioned JSON Schemas and public synthetic conformance vectors.

The package must not depend on SwiftUI, UIKit, Network.framework, CANboat, Signal K runtime types, a database, HelmBrain, or an Apple-only domain API. Foundation may support serialization at the edge. Core behavior uses ordinary strongly typed Swift and structured concurrency where asynchronous provider streams require it.

Executable command dispatch, control binding leases, plugin hosting, networking, persistence, transport adapters, and application policy are not part of the initial read-only tranche. Command outcome and qualification semantics remain specified so later implementation cannot redefine them accidentally.

## Portability and conformance

JSON Schema 2020-12 is selected for serialized contract and fixture validation. Behavioral semantics that cannot be expressed by schema are defined in normative prose and input/expected-result vectors using controlled time.

Future implementations—such as Kotlin for Android—should use idiomatic native APIs and must pass the same conformance vectors. Code generation may create data-transfer models where useful, but must not replace review of language-specific lifecycle, concurrency, and safety behavior.

A shared Rust, Kotlin Multiplatform, or other binary runtime is a future possibility only after at least one additional client or measured duplication/performance cost justifies its build, FFI, and debugging complexity.

## Versioning

- The specification, schemas, conformance vectors, and Swift package use coordinated semantic versions while pre-1.0.
- Schemas carry stable `$id` values and explicit version identity.
- Consumers pin exact pre-1.0 tags or commits.
- Compatibility is demonstrated by conformance, not assumed from compilation alone.
- Breaking semantic changes require release notes, migrated vectors, and an explicit decision.

## Rationale

This approach supplies the smallest executable component HelmBrain HB-001 needs while preserving VesselLayer's independence. Swift provides the fastest, most inspectable reference path for the first iPad consumer. Technology-neutral schemas and conformance vectors preserve an honest Android/other-language path without imposing a shared runtime before its benefits exist.

See HelmBrain's [`HB-IMPLEMENTATION-ARCHITECTURE-001`](https://github.com/mammut3/HelmBrain/blob/main/docs/decisions/HB-IMPLEMENTATION-ARCHITECTURE-001.md) for the client, gateway, CANboat, Signal K, replay, and future-client tradeoff analysis.
