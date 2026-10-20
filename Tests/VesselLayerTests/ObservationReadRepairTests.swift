import Testing
@testable import VesselLayer

@Suite("Observation read repair contracts")
struct ObservationReadRepairTests {
    let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider", observationIDs: [.navigationPosition])
    let policy = ReadAuthorityPolicy(freshness: .init(freshForNanoseconds: 5_000_000_000))

    @Test func removedUnavailableGenerationCannotBecomeAuthoritative() async throws {
        let clock = ReadRepairClock()
        // Use one clock so the read is suspended exactly before its snapshot.
        let controlled = VesselObservationStore(clock: clock)
        await controlled.register(descriptor)
        await controlled.updateProvider(descriptor.id, lifecycle: .unavailable, health: .unhealthy)
        await controlled.ingest(sample(at: 1))
        await clock.arm()
        let read = Task { await controlled.authority(for: .navigationPosition, policy: policy) }
        try await clock.waitUntilHeld()
        await controlled.removeProvider(descriptor.id)
        await controlled.register(descriptor)
        await controlled.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await clock.release()
        #expect(await read.value.observation == nil)
        #expect(await controlled.allCandidates(for: .navigationPosition).isEmpty)
    }

    @Test func sourceMapAndCapabilityUseOneClockSnapshotEach() async {
        let clock = ReadRepairClock()
        let controlled = VesselObservationStore(clock: clock)
        await controlled.register(descriptor)
        await controlled.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await controlled.ingest(sample(at: 1))
        await clock.resetCount()
        let map = await controlled.sourceMapEntry(for: .navigationPosition, policy: policy)
        #expect(await clock.count == 1)
        #expect(map.candidates.first?.isAuthoritative == true)
        await clock.resetCount()
        let capability = await controlled.readCapability(for: .navigationPosition, id: .init(rawValue: "position"), policy: policy)
        #expect(await clock.count == 1)
        #expect(capability.availability == .available)
        await controlled.withdrawProvider(descriptor.id)
        #expect(await controlled.readCapability(for: .navigationPosition, id: .init(rawValue: "position"), policy: policy).availability == .unavailable)
    }

    @Test(arguments: [false, true]) func withdrawalDuringReadClockIsReflected(capability: Bool) async throws {
        let clock = ReadRepairClock()
        let controlled = VesselObservationStore(clock: clock)
        await controlled.register(descriptor)
        await controlled.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await controlled.ingest(sample(at: 1))
        await clock.arm()
        let read = Task {
            if capability {
                return await controlled.readCapability(for: .navigationPosition, id: .init(rawValue: "position"), policy: policy).availability == .available
            }
            return await controlled.sourceMapEntry(for: .navigationPosition, policy: policy).candidates.contains(where: \.isAuthoritative)
        }
        try await clock.waitUntilHeld()
        await controlled.withdrawProvider(descriptor.id)
        await clock.release()
        #expect(await read.value == false)
    }

    @Test func latestSlotRejectsOlderValidAndInvalidCompletionAndKeepsEqualArrivalOrder() async {
        let store = VesselObservationStore(clock: ReadRepairClock())
        await store.register(descriptor)
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await store.ingest(sample(at: 4_000_000_000))
        await store.ingest(sample(at: 1_000_000_000))
        #expect(await store.allCandidates(for: .navigationPosition).first?.receivedAt.nanoseconds == 4_000_000_000)
        var invalid = sample(at: 2_000_000_000); invalid.validity = .invalid
        await store.ingest(invalid)
        #expect(await store.allCandidates(for: .navigationPosition).first?.validity == .valid)
        var equal = sample(at: 4_000_000_000); equal.validity = .invalid
        await store.ingest(equal)
        #expect(await store.allCandidates(for: .navigationPosition).first?.validity == .invalid)
    }

    private func sample(at: UInt64) -> AnyObservation {
        .init(id: .navigationPosition, value: .position(.init(latitudeDegrees: 1, longitudeDegrees: 2)), source: .init(providerID: descriptor.id), receivedAt: .init(nanoseconds: at))
    }
}

private actor ReadRepairClock: VesselLayerClock {
    var count = 0
    private var armed = false
    private var held: CheckedContinuation<MonotonicInstant, Never>?
    func resetCount() { count = 0 }
    func arm() { armed = true }
    func now() async -> MonotonicInstant {
        count += 1
        guard armed else { return .init(nanoseconds: 4_000_000_000) }
        armed = false
        return await withCheckedContinuation { held = $0 }
    }
    func waitUntilHeld() async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while held == nil {
            if ContinuousClock.now >= deadline { throw ClockFailure.deadline }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func release() { let waiting = held; held = nil; waiting?.resume(returning: .init(nanoseconds: 4_000_000_000)) }
    enum ClockFailure: Error { case deadline }
}
