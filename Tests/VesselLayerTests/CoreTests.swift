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

    private func heading(provider: ProviderID, value: Double, time: MonotonicInstant) -> AnyObservation {
        AnyObservation(id: .navigationHeading, value: .heading(.init(radians: value, reference: .trueNorth)),
                       source: .init(providerID: provider), receivedAt: time)
    }
}
