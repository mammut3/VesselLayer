# VesselLayer

> **VesselLayer is an open, vendor-neutral capability framework for marine applications. It represents what a vessel can observe and do independently of the underlying protocols, devices, manufacturers, transports, and applications.**

VesselLayer is the semantic seam between marine infrastructure and application behavior. Marine applications should not need to understand transports, PGNs/messages, manufacturers, or individual device APIs before they can answer:

> What can this vessel observe and do?

HelmBrain is VesselLayer's first consumer and primary initial proving application, but VesselLayer is application-neutral and intended to be independently useful.

## Architecture

```text
CANboat / NMEA 2000       Signal K       OneNet       Other providers
         \                   |              |                /
          \                  |              |               /
           └──────────── adapters/providers ───────────────┘
                              |
                         VesselLayer
                              |
                  ┌───────────┼───────────┐
                  |           |           |
               HelmBrain   Other Apps   Simulators
```

CANboat, NMEA 2000, Signal K, and OneNet are examples and prior art, not required runtime dependencies. Physical/network discovery, protocol decoding, vendor behavior, and transport sessions stay in adapters. VesselLayer receives transport-neutral asset/provider evidence, observations, capabilities, qualification evidence, and operation results.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/GLOSSARY.md](docs/GLOSSARY.md), and [docs/CONFORMANCE.md](docs/CONFORMANCE.md).

## Initial scope

VesselLayer specifies the smallest useful contracts around vessels, assets, providers, observations, capabilities, operations, qualification/evidence, source authority, availability, command requests/outcomes, provider lifecycle, deterministic resolution, controlled clocks, and conformance fixtures.

Discovery, provider matching, qualification, authorization, and current availability remain distinct. Recognizing a device or matching a provider never grants control authority. VesselLayer represents evidence; it does not certify equipment as safe.

## Non-goals

VesselLayer is not:

- an NMEA 2000 stack, CAN parser, PGN database, CANboat replacement, or gateway/W2K-2 driver;
- Signal K, a Signal K fork, or a Signal K server;
- an NMEA/OneNet/BLE/proprietary device-discovery implementation;
- a chartplotter, MFD, chart engine, route planner, or geodesic library;
- an autopilot, throttle controller, or physical control loop;
- a workflow/rules engine, cloud platform, plugin marketplace, or UI framework; or
- a fishing framework or home for HelmBrain-specific Reverse Troll, Repeat Pass, Return to Bite, or other application behavior.

## Status

VesselLayer is **early-stage and pre-1.0**. Its contracts will evolve as they are validated against multiple real marine systems and applications. It is not safety certified, does not certify connected equipment, and must not be treated as proof that a control path is safe or authorized.

The normative specification and conformance artifacts remain technology-neutral. The selected initial executable implementation is a small pure-Swift reference package distributed with Swift Package Manager, with JSON Schema 2020-12 used for serialized contracts and conformance fixtures. The Swift API does not become the cross-language specification. See [docs/IMPLEMENTATION_ARCHITECTURE.md](docs/IMPLEMENTATION_ARCHITECTURE.md).

Build and test the reference implementation with `swift test`. `VesselLayer`
contains portable runtime contracts and deterministic read-source selection;
`VesselLayerTesting` supplies a manual monotonic clock and synthetic-provider
helpers. Swift tests execute the public cross-language vectors in `fixtures`.

## AI-assisted development

VesselLayer is developed with substantial assistance from AI coding and research tools. Human maintainers direct the project, make architectural and product decisions, review changes, validate behavior, and remain responsible for accepted contributions.

AI-assisted contributions are held to the same standards for testing, provenance, licensing, security, and review as human-written contributions. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under the [Apache License 2.0](LICENSE). This repository does not redistribute proprietary NMEA specifications and does not claim NMEA certification.
