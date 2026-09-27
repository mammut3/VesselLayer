# Conceptual Examples

These examples are technology-neutral and illustrative, not a selected wire format or API.

## Two position providers

GPS provider A and AIS provider B both publish `navigation.position`. VesselLayer retains both observations with source, time, validity, freshness, quality, and qualification evidence. Vessel policy prefers A while it is valid and fresh, otherwise selects eligible B. A stable policy tie-breaker—not registration or arrival order—makes the result deterministic.

## Equivalent steering capabilities

Two adapters expose the semantic operation `steering.adjustHeading`. One may represent Raymarine equipment and another a different manufacturer. Application code requests the operation from the resolved, eligible steering provider without branching on manufacturer or transport.

## Matched but not qualified

A discovered asset matches a steering provider fingerprint and contributes a potential `steering.adjustHeading` capability. Its read observations may be available, but the control operation remains unavailable because vessel-specific control qualification evidence is absent. Provider matching does not grant authorization.

## Uncertain command outcome

An application issues a heading adjustment. The provider transmits the underlying command but receives no observable confirmation before timeout. The outcome is `uncertain`, not success. The framework does not automatically replay the command after reconnect or restart.
