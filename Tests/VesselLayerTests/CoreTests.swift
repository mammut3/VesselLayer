import Foundation
import Testing
@testable import VesselLayer
import VesselLayerTesting

@Suite("VesselLayer read authority") struct CoreTests {
    let policy = ReadAuthorityPolicy(freshness: FreshnessPolicy(freshFor: .seconds(5)))

    @Test func identifiersAreStableAndSortable() throws {
        let encoded = try JSONEncoder().encode(ProviderID(rawValue: "provider-a"))
        #expect(try JSONDecoder().decode(ProviderID.self, from: encoded) == ProviderID(rawValue: "provider-a"))
        #expect(ProviderID(rawValue: "a") < ProviderID(rawValue: "b"))
    }

    @Test func registrationLifecycleAndWithdrawal() async {
        let clock = ManualClock()
        let store = VesselObservationStore(clock: clock)
        let descriptor = TestProviders.descriptor("provider-a")
        let registered = await store.register(descriptor)
        #expect(registered.lifecycle == .registered)
        #expect(registered.availability == .unavailable)
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        #expect(await store.providerState(descriptor.id)?.availability == .available)
        await store.withdrawProvider(descriptor.id)
        #expect(await store.providerState(descriptor.id)?.availability == .withdrawn)
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        #expect(await store.providerState(descriptor.id)?.lifecycle == .withdrawn)
    }

    @Test func manualClockDrivesFreshnessAndFailover() async {
        let clock = ManualClock()
        let store = VesselObservationStore(clock: clock)
        let a = TestProviders.descriptor("a")
        let b = TestProviders.descriptor("b")
        _ = await store.register(a); _ = await store.register(b)
        await store.updateProvider(a.id, lifecycle: .present, health: .healthy)
        await store.updateProvider(b.id, lifecycle: .present, health: .healthy)
        await store.ingest(heading(provider: a.id, value: 1, time: await clock.now()))
        await clock.advance(by: .seconds(4))
        await store.ingest(heading(provider: b.id, value: 2, time: await clock.now()))
        let ranked = ReadAuthorityPolicy(providerRanks: [a.id: 0, b.id: 1], freshness: policy.freshness)
        #expect(await store.authority(for: .navigationHeading, policy: ranked).observation?.source.providerID == a.id)
        await clock.advance(by: .seconds(2))
        let failover = await store.authority(for: .navigationHeading, policy: ranked)
        #expect(failover.observation?.source.providerID == b.id)
        #expect(failover.reason == .selectedOnlyEligibleCandidate)
    }

    @Test func arrivalOrderNeverBreaksTies() async {
        for reverse in [false, true] {
            let clock = ManualClock()
            let store = VesselObservationStore(clock: clock)
            let a = TestProviders.descriptor("a"), b = TestProviders.descriptor("b")
            _ = await store.register(a); _ = await store.register(b)
            await store.updateProvider(a.id, lifecycle: .present, health: .healthy)
            await store.updateProvider(b.id, lifecycle: .present, health: .healthy)
            let values = [heading(provider: a.id, value: 1, time: await clock.now()), heading(provider: b.id, value: 2, time: await clock.now())]
            for value in reverse ? values.reversed() : values { await store.ingest(value) }
            let decision = await store.authority(for: .navigationHeading, policy: policy)
            #expect(decision.observation?.source.providerID == a.id)
            #expect(decision.reason == .selectedByStableProviderID)
        }
    }

    @Test func invalidStaleAndUnavailableCandidatesAreIneligible() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        let a = TestProviders.descriptor("a"); _ = await store.register(a)
        await store.updateProvider(a.id, lifecycle: .present, health: .healthy)
        var invalid = heading(provider: a.id, value: 1, time: await clock.now()); invalid.validity = .invalid
        await store.ingest(invalid)
        #expect(await store.authority(for: .navigationHeading, policy: policy).reason == .noEligibleCandidates)
        var valid = invalid; valid.validity = .valid; await store.ingest(valid)
        await store.updateProvider(a.id, lifecycle: .unavailable, health: .unhealthy)
        #expect(await store.authority(for: .navigationHeading, policy: policy).reason == .noEligibleCandidates)
    }

    @Test func preservesMultipleCandidates() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        for id in ["b", "a"] {
            let descriptor = TestProviders.descriptor(id); _ = await store.register(descriptor)
            await store.ingest(heading(provider: descriptor.id, value: 1, time: await clock.now()))
        }
        #expect(await store.allCandidates(for: .navigationHeading).map(\.source.providerID) == [ProviderID(rawValue: "a"), ProviderID(rawValue: "b")])
    }

    @Test func reconcilesProvisionalProviderWithoutDuplicateCandidate() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        let provisional = TestProviders.descriptor("session-source")
        let durable = ProviderDescriptor(id: .init(rawValue: "durable-node"),
                                         vesselID: provisional.vesselID,
                                         assetID: .init(rawValue: "durable-asset"),
                                         label: "Durable node")
        _ = await store.register(provisional)
        await store.updateProvider(provisional.id, lifecycle: .present, health: .healthy)
        await store.ingest(heading(provider: provisional.id, value: 1, time: await clock.now()))

        await store.reconcileProvider(from: provisional.id, to: durable)

        #expect(await store.providerState(provisional.id) == nil)
        #expect(await store.providerState(durable.id)?.availability == .available)
        let migrated = await store.allCandidates(for: .navigationHeading)
        #expect(migrated.count == 1)
        #expect(migrated[0].source.providerID == durable.id)
        #expect(migrated[0].source.assetID == durable.assetID)
    }

    @Test func reconciliationKeepsNewestDurableCandidateAndRemovalPrunesState() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        let provisional = TestProviders.descriptor("session-source")
        let durable = TestProviders.descriptor("durable-node")
        _ = await store.register(provisional); _ = await store.register(durable)
        await store.ingest(heading(provider: provisional.id, value: 1, time: await clock.now()))
        await clock.advance(by: .seconds(1))
        await store.ingest(heading(provider: durable.id, value: 2, time: await clock.now()))

        await store.reconcileProvider(from: provisional.id, to: durable)
        let candidates = await store.allCandidates(for: .navigationHeading)
        #expect(candidates.count == 1)
        #expect(candidates[0].source.providerID == durable.id)
        #expect(candidates[0].receivedAt.nanoseconds == 1_000_000_000)

        await store.removeProvider(durable.id)
        #expect(await store.allProviderStates().isEmpty)
        #expect(await store.allCandidates(for: .navigationHeading).isEmpty)
    }

    @Test func assetInventoryPreservesIdentityAcrossLifecycleAndEnrichment() async {
        let inventory = AssetInventory()
        let id = AssetID(rawValue: "synthetic-heading-unit")
        let vessel = VesselID(rawValue: "test-vessel")
        let partial = AssetDescriptor(id: id, vesselID: vessel, roles: ["headingSource"])
        let first = await inventory.observe(partial, at: .init(nanoseconds: 10),
                                            identityState: .partial)
        #expect(first.change == .new)
        #expect(first.state.firstSeenAt.nanoseconds == 10)

        let missing = await inventory.markMissing(id, at: .init(nanoseconds: 20))
        #expect(missing?.change == .missing)
        #expect(missing?.state.presence == .missing)
        #expect(missing?.state.lastSeenAt.nanoseconds == 10)
        #expect(missing?.state.updatedAt.nanoseconds == 20)

        let enriched = AssetDescriptor(id: id, vesselID: vessel, label: "Synthetic heading unit",
                                       manufacturer: "Example Marine", model: "H-1",
                                       softwareVersion: "1.2", roles: ["headingSource"])
        let returned = await inventory.observe(enriched, at: .init(nanoseconds: 30),
                                               health: .healthy, identityState: .identified)
        #expect(returned.change == .reappeared)
        #expect(returned.state.descriptor.manufacturer == "Example Marine")
        #expect(returned.state.firstSeenAt.nanoseconds == 10)
        #expect(returned.state.lastSeenAt.nanoseconds == 30)
        #expect(await inventory.allStates().count == 1)
    }

    @Test func assetIdentityAmbiguityIsIndependentFromPresence() async {
        let inventory = AssetInventory()
        let descriptor = AssetDescriptor(id: .init(rawValue: "ambiguous"),
                                         vesselID: .init(rawValue: "test-vessel"))
        let update = await inventory.observe(descriptor, at: .init(nanoseconds: 1),
                                             health: .healthy, identityState: .ambiguous,
                                             evidenceIDs: [.init(rawValue: "claim-a"), .init(rawValue: "claim-b")])
        #expect(update.change == .ambiguous)
        #expect(update.state.presence == .present)
        #expect(update.state.identityState == .ambiguous)
    }

    @Test func sourceMapPreservesCandidatesAndExplainsAuthority() async {
        let clock = ManualClock()
        let store = VesselObservationStore(clock: clock)
        let a = ProviderDescriptor(id: .init(rawValue: "a"), vesselID: .init(rawValue: "v"),
                                   assetID: .init(rawValue: "asset-a"), label: "A",
                                   observationIDs: [.navigationHeading])
        let b = ProviderDescriptor(id: .init(rawValue: "b"), vesselID: .init(rawValue: "v"),
                                   assetID: .init(rawValue: "asset-b"), label: "B",
                                   observationIDs: [.navigationHeading])
        _ = await store.register(a); _ = await store.register(b)
        await store.updateProvider(a.id, lifecycle: .present, health: .healthy)
        await store.updateProvider(b.id, lifecycle: .present, health: .healthy)
        await store.ingest(heading(provider: a.id, value: 1, time: await clock.now()))
        await clock.advance(by: .seconds(4))
        await store.ingest(heading(provider: b.id, value: 2, time: await clock.now()))

        let ranked = ReadAuthorityPolicy(providerRanks: [a.id: 0, b.id: 1], freshness: policy.freshness)
        var map = await store.sourceMapEntry(for: .navigationHeading, policy: ranked)
        #expect(map.candidates.count == 2)
        #expect(map.candidates.first(where: { $0.observation.source.providerID == a.id })?.isAuthoritative == true)
        #expect(map.candidates.first(where: { $0.observation.source.providerID == a.id })?.authorityReason == .selectedByPolicyRank(rank: 0))
        #expect(map.authorityReason == .selectedByPolicyRank(rank: 0))

        await clock.advance(by: .seconds(2))
        map = await store.sourceMapEntry(for: .navigationHeading, policy: ranked)
        #expect(map.candidates.first(where: { $0.observation.source.providerID == a.id })?.freshness == .stale)
        #expect(map.candidates.first(where: { $0.observation.source.providerID == b.id })?.isAuthoritative == true)
        let capability = await store.readCapability(for: .navigationHeading,
                                                    id: .init(rawValue: "navigation.heading.read"),
                                                    policy: ranked)
        #expect(capability.availability == .available)
        #expect(capability.providerIDs == [a.id, b.id])
    }

    @Test func declarationWithoutObservationIsPotentialNotAvailable() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        let provider = ProviderDescriptor(id: .init(rawValue: "declared-heading"),
                                          vesselID: .init(rawValue: "v"), label: "Heading",
                                          observationIDs: [.navigationHeading])
        _ = await store.register(provider)
        await store.updateProvider(provider.id, lifecycle: .present, health: .healthy)
        let capability = await store.readCapability(for: .navigationHeading,
                                                    id: .init(rawValue: "navigation.heading.read"),
                                                    policy: policy)
        #expect(capability.availability == .potential)
        #expect(capability.providerIDs == [provider.id])
    }

    @Test func staleSourcesMakeReadCapabilityUnavailableWithoutDiscardingCandidates() async {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        let provider = TestProviders.descriptor("heading")
        _ = await store.register(provider)
        await store.updateProvider(provider.id, lifecycle: .present, health: .healthy)
        await store.ingest(heading(provider: provider.id, value: 1, time: await clock.now()))
        await clock.advance(by: .seconds(6))
        let capability = await store.readCapability(for: .navigationHeading,
                                                    id: .init(rawValue: "navigation.heading.read"),
                                                    policy: policy)
        #expect(capability.availability == .unavailable)
        #expect(capability.providerIDs == [provider.id])
    }

    @Test func matchingAndQualificationNeverImplyControlAvailability() throws {
        let provider = ProviderID(rawValue: "autopilot-provider")
        let asset = AssetID(rawValue: "autopilot-asset")
        let evidence = EvidenceReference(id: .init(rawValue: "observed-model"), kind: "productIdentity",
                                         summary: "Adapter observed a compatible model")
        let match = ProviderMatch(providerID: provider, assetID: asset, state: .matched,
                                  evidence: [evidence], explanation: "Explicit identity evidence matched.")
        let capability = CapabilityState(id: .init(rawValue: "steering.control"),
                                         kind: .operation(.init(rawValue: "steering.setHeading")),
                                         availability: .unqualified, providerIDs: [provider],
                                         evidenceIDs: [evidence.id],
                                         reason: "Observed equipment is not control-qualified.")
        #expect(match.state == .matched)
        #expect(capability.availability == .unqualified)
        #expect(capability.availability != .available)
        #expect(try JSONDecoder().decode(ProviderMatch.self,
                                        from: JSONEncoder().encode(match)) == match)
    }

    private func heading(provider: ProviderID, value: Double, time: MonotonicInstant) -> AnyObservation {
        AnyObservation(id: .navigationHeading, value: .heading(.init(radians: value, reference: .trueNorth)),
                       source: .init(providerID: provider), receivedAt: time)
    }
}
