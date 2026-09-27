# VesselLayer Architecture

## Purpose

VesselLayer answers: **What can this vessel observe and do?** It provides transport-neutral contracts between marine adapters/providers and applications. HelmBrain is the first proving application, not the owner of VesselLayer's product behavior.

```text
marine transports, protocols, devices, simulators, and external systems
                              ↓
                    adapters and providers
                              ↓
                         VesselLayer
                              ↓
                         applications
```

Dependencies point inward through the provider boundary. VesselLayer core contracts never require PGNs, CAN addresses, CAN NAME, Actisense framing, W2K-2 sessions, Signal K runtime types, BLE characteristics, or manufacturer APIs. Adapters may retain those details as opaque provenance/evidence while emitting generic descriptors and observations.

## Core model

- **Vessel** scopes assets, policy, evidence, provider resolution, and capabilities.
- **Asset descriptor** describes an observed logical or physical asset using stable generic identity plus opaque provenance/evidence.
- **Provider descriptor** declares the observations and operations a provider may supply, its constraints, health, and lifecycle state.
- **Observation** is a source-aware value with semantic identity, time, validity, freshness, quality, and provenance.
- **Capability** describes a semantic observation or action the vessel may offer.
- **Operation** describes semantic command intent, requirements, constraints, and possible outcomes.
- **Qualification/evidence** records what was declared, observed, replay validated, vessel validated for reading, vessel validated for a specific control operation, or revoked.
- **Authority policy** deterministically resolves equivalent providers/sources for a stated purpose.
- **Availability** is current runtime usability after presence, health, dependencies, qualification, authorization, and constraints are evaluated.

Asset Inventory, Data Source Map, provider matching, Capability Map, qualification, authorization, and availability are related but distinct. Implementations should not force them into one monotonic enum when orthogonal state is clearer.

## Provider boundary and lifecycle

Physical/network discovery remains transport-specific:

```text
NMEA 2000 discovery messages
        ↓
NMEA adapter
        ↓
transport-neutral asset/provider evidence
        ↓
VesselLayer
```

The same contracts should accept providers originating from NMEA 2000, Signal K, OneNet, BLE, proprietary Ethernet/APIs, replay, simulators, and future transports.

Provider lifecycle distinguishes declaration/registration, presence, health, disappearance, reappearance, and withdrawal. Registration or arrival order never establishes authority. A provider may be present but unavailable, matched but unqualified, qualified but unauthorized, or authorized but currently unhealthy.

## Source authority

Multiple providers may publish equivalent observations. Resolution is deterministic and policy-driven. Inputs may include vessel/user policy, purpose, qualification, validity, freshness, quality, provider health, and a stable tie-breaker. VesselLayer supplies the contract and deterministic mechanism; applications supply policy without embedding application-specific behavior in core.

## Qualification and authorization

Qualification is evidence, not certification. It can represent declared support, observation, replay validation, vessel read validation, operation-specific vessel control validation, and revocation. Control qualification is scoped to the provider, asset/configuration, operation, implementation version, vessel, and evidence.

Recognizing a manufacturer/model, matching a provider, or receiving valid data never grants control authority. Authorization remains a separate policy decision. Current availability also depends on live health, prerequisites, and constraints.

## Commands and outcomes

A command request carries semantic operation identity, arguments, correlation/idempotency identity, constraints, and cancellation context. Outcomes distinguish at least:

- accepted;
- acknowledged or completed where observable;
- rejected;
- unsupported;
- timed out;
- cancelled; and
- uncertain.

Writing bytes is not success. An uncertain outcome is never reported as success, retryability is explicit, and commands are not automatically replayed after reconnect or restart.

## Time and conformance seams

Clocks and scheduling are injectable so freshness, timeouts, provider disappearance, and deterministic resolution can be tested with controlled time. Technology-neutral fixtures and expected results define behavior across implementations.

## Initial implementation

VesselLayer's normative contract remains technology-neutral. JSON Schema 2020-12 represents serialized descriptors, evidence, and conformance fixtures; normative prose and input/expected-result vectors specify behavior.

The initial executable reference is a pure-Swift package with a small core library and test-support target. It implements the read-only provider/observation/authority surface required by the first consumer without SwiftUI, networking, protocol decoders, databases, or application policy. Future native implementations must pass the same conformance suite; no shared binary runtime is required. See [IMPLEMENTATION_ARCHITECTURE.md](IMPLEMENTATION_ARCHITECTURE.md).

## Non-goals and ownership

VesselLayer does not implement marine transports/protocols, NMEA discovery, codecs, charts, routes, geodesy, physical control loops, workflow engines, cloud services, plugin hosting, UI, or application features. Signal K is important semantic/provider prior art and a future adapter target, not a runtime dependency or core type system. CANboat and gateway SDKs remain below adapters.

Applications own product policy, UX, workflows, authorization, and domain behavior. HelmBrain therefore owns fishing intelligence, maneuvers, Reverse Troll, Repeat Pass, Return to Bite, and its iPad experience outside VesselLayer.
