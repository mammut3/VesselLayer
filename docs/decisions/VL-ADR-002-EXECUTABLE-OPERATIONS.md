# VL-ADR-002 — Executable operation and capability boundary

- **Status:** Accepted for the next implementation tranche
- **Date:** 2026-09-30

## Decision

VesselLayer owns the stable, generic executable-operation seam: operation
descriptor and identifier; request/correlation identity; idempotency identity
where an operation requires it; deadline; cancellation; generic availability and
preconditions; capability constraints; operation outcome/status; and the explicit
relationship between qualification and supporting evidence.

These contracts remain transport neutral, vendor neutral, and application
neutral. They describe what can be requested and how its status and evidence are
represented; they do not implement a physical closed-loop controller.

VesselLayer does not own Raymarine PGNs, Actisense sessions, provider
installation, HelmBrain UI, fishing workflows, Fishing Turn, Fish On, Return to
Bite, Repeat Pass, or physical closed-loop control. HelmBrain product/application
behavior owns fishing intent and orchestrates it over generic operations.

## Implementation sequence

HB-ARCH-003B will add the smallest generic contract and adapt the existing
Raymarine provider through compatibility boundaries. The existing Raymarine
provider is the first proven executable evidence.

**Do not implement throttle or another real steering provider merely to justify
the abstraction.** Do not add dispatchers, provider registries, plugin machinery,
or application workflows to VesselLayer as part of this decision record.

## Rationale

The current read-side model and generic outcome vocabulary already establish the
correct ownership direction. Recording the command-side boundary now prevents
HelmBrain's single-provider types from becoming a second public capability system,
while deferring API shape and conformance implementation to the bounded 003B
tranche.
