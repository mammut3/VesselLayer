# Glossary

- **Vessel** — the scope within which assets, providers, policy, evidence, and capabilities are resolved.
- **Asset** — an observed logical or physical vessel component described by stable generic identity and evidence; it is not inherently a provider or capability.
- **Provider** — an adapter-backed participant that offers observations or operations through VesselLayer contracts.
- **Observation** — a source-aware semantic value with time, validity, freshness, quality, and provenance.
- **Capability** — a semantic statement of what the vessel may observe or do, contributed by one or more providers.
- **Operation** — a semantic action that a provider may execute, including requirements, constraints, and possible outcomes.
- **Qualification** — evidence-backed confidence for a specific provider, asset/configuration, capability or operation, implementation version, and vessel context. It is not safety certification or authorization.
- **Evidence** — a traceable record supporting identity, behavior, matching, validation, qualification, or revocation.
- **Authority** — deterministic policy selecting which eligible provider supplies a semantic observation or operation for a purpose.
- **Availability** — whether a capability or operation is currently usable after presence, health, dependencies, qualification, authorization, and constraints are considered.
- **Command** — a request to perform a semantic operation with arguments, correlation identity, constraints, and cancellation context.
- **Command Outcome** — the honest result state of a command, including accepted, completed/acknowledged, rejected, unsupported, timed out, cancelled, or uncertain.
