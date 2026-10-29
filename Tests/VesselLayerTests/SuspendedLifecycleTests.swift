import Testing
@testable import VesselLayer

@Suite("Suspended provider lifecycle") struct SuspendedLifecycleTests {
    @Test(arguments: [false, true]) func pendingUpdateCannotReviveTerminalProvider(remove: Bool) async throws {
        let clock = HeldLifecycleClock()
        let store = VesselObservationStore(clock: clock)
        let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        await store.register(descriptor)
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await store.ingest(.init(id: .navigationHeading, value: .heading(.init(radians: 1, reference: .trueNorth)),
            source: .init(providerID: descriptor.id), receivedAt: .init(nanoseconds: 1)))
        await clock.arm()
        let update = Task { await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy) }
        try await clock.waitUntilHeld()
        if remove { await store.removeProvider(descriptor.id) } else { await store.withdrawProvider(descriptor.id) }
        await clock.release()
        await update.value
        let state = await store.providerState(descriptor.id)
        #expect(remove ? state == nil : state?.lifecycle == .withdrawn)
        #expect(await store.authority(for: .navigationHeading,
            policy: .init(freshness: .init(freshFor: .seconds(5)))).observation == nil)
        if remove {
            #expect(await store.allCandidates(for: .navigationHeading).isEmpty)
            await store.register(descriptor)
            await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
            #expect(await store.providerState(descriptor.id)?.availability == .available)
        } else {
            #expect(await store.allCandidates(for: .navigationHeading).count == 1)
            #expect(await store.register(descriptor).lifecycle == .withdrawn)
        }
    }

    @Test(arguments: [false, true]) func olderAvailabilityCompletionCannotOverwriteNewerIntent(reregister: Bool) async throws {
        let clock = HeldLifecycleClock()
        let store = VesselObservationStore(clock: clock)
        let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        await store.register(descriptor)
        await clock.arm()
        let old = Task { await store.updateProvider(descriptor.id, lifecycle: .unavailable, health: .unhealthy) }
        try await clock.waitUntilHeld()
        if reregister { await store.removeProvider(descriptor.id); await store.register(descriptor) }
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await clock.release(); await old.value
        #expect(await store.providerState(descriptor.id)?.availability == .available)
    }

    @Test func withdrawalRemainsTerminalWithinTheSameRegistration() async throws {
        let clock = HeldLifecycleClock()
        let controlled = VesselObservationStore(clock: clock)
        let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        await controlled.register(descriptor)
        let registration = await controlled.providerRegistrations()[descriptor.id]
        await clock.arm()
        let withdrawal = Task { await controlled.withdrawProvider(descriptor.id) }
        try await clock.waitUntilHeld()
        await controlled.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        await clock.release()
        await withdrawal.value
        #expect(await controlled.providerState(descriptor.id)?.lifecycle == .withdrawn)
        await controlled.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        #expect(await controlled.providerState(descriptor.id)?.lifecycle == .withdrawn)
        #expect(await controlled.providerRegistrations()[descriptor.id] == registration)
    }

    @Test func pendingWithdrawalCannotRestoreRemovedProvider() async throws {
        let clock = HeldLifecycleClock()
        // Use the same controlled clock at every production suspension.
        let controlled = VesselObservationStore(clock: clock)
        let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        await controlled.register(descriptor)
        await clock.arm()
        let withdrawal = Task { await controlled.withdrawProvider(descriptor.id) }
        try await clock.waitUntilHeld()
        await controlled.removeProvider(descriptor.id)
        await clock.release()
        await withdrawal.value
        #expect(await controlled.providerState(descriptor.id) == nil)
    }

    @Test func sameIdentityReconciliationCannotRestoreRemovedProvider() async throws {
        let clock = HeldLifecycleClock(), descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        let store = VesselObservationStore(clock: clock)
        await store.register(descriptor)
        await clock.arm()
        let reconciliation = Task { await store.reconcileProvider(from: descriptor.id, to: descriptor) }
        try await clock.waitUntilHeld()
        await store.removeProvider(descriptor.id)
        await clock.release()
        await reconciliation.value
        #expect(await store.providerState(descriptor.id) == nil)
    }

    @Test func pendingRegistrationPreservesCompletedRegistrationAndWithdrawal() async throws {
        let clock = HeldLifecycleClock()
        let controlled = VesselObservationStore(clock: clock)
        let descriptor = ProviderDescriptor(id: .init(rawValue: "provider"), vesselID: .init(rawValue: "vessel"), label: "Provider")
        await clock.arm()
        let registration = Task { await controlled.register(descriptor) }
        try await clock.waitUntilHeld()
        await controlled.register(descriptor)
        await controlled.withdrawProvider(descriptor.id)
        await clock.release()
        #expect(await registration.value.lifecycle == .withdrawn)
        #expect(await controlled.providerState(descriptor.id)?.lifecycle == .withdrawn)
    }
}

private actor HeldLifecycleClock: VesselLayerClock {
    private var armed = false
    private var held: CheckedContinuation<MonotonicInstant, Never>?
    func arm() { armed = true }
    func now() async -> MonotonicInstant {
        guard armed else { return .init(nanoseconds: 1) }
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
    func release() { let waiting = held; held = nil; waiting?.resume(returning: .init(nanoseconds: 1)) }
    enum ClockFailure: Error { case deadline }
}
