import Foundation
import Testing
@testable import VesselLayer

private struct RegistrationVectors: Decodable {
    let schemaVersion: String
    let vectors: [RegistrationVector]
}
private struct RegistrationVector: Decodable {
    let id: String
    let operation: String
    let replacement: String
    let targetInitiallyPresent: Bool
    let expected: String
}

@Test func publicRegistrationOwnershipVectors() async throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../fixtures/conformance/0.1.0/provider-registration-ownership.json")
        .standardizedFileURL
    let vectors = try JSONDecoder().decode(RegistrationVectors.self, from: Data(contentsOf: url))
    #expect(vectors.schemaVersion == "0.1.0")
    for vector in vectors.vectors {
        let clock = RegistrationClock()
        // Every production suspension in this vector uses the same controlled clock.
        let controlled = VesselObservationStore(clock: clock)
        let source = ProviderDescriptor(id: .init(rawValue: "source"), vesselID: .init(rawValue: "vessel"), label: "Original")
        let target = ProviderDescriptor(id: .init(rawValue: "target"), vesselID: source.vesselID, label: "Target")
        await controlled.register(source)
        if vector.targetInitiallyPresent { await controlled.register(target) }
        let originalRegistrations = await controlled.providerRegistrations()
        await clock.arm()
        let operation = Task {
            switch vector.operation {
            case "withdraw": await controlled.withdrawProvider(source.id)
            case "reconcileSame":
                var renamed = source; renamed.label = "Old operation descriptor"
                await controlled.reconcileProvider(from: source.id, to: renamed)
            case "reconcileDifferent": await controlled.reconcileProvider(from: source.id, to: target)
            default: Issue.record("Unknown operation in \(vector.id)")
            }
        }
        try await clock.waitUntilHeld()
        var replacement = vector.replacement == "source" ? source : target
        replacement.label = "Replacement"
        await controlled.removeProvider(replacement.id)
        await controlled.register(replacement)
        await controlled.updateProvider(replacement.id, lifecycle: .present, health: .healthy)
        await controlled.ingest(.init(id: .navigationHeading, value: .heading(.init(radians: 2, reference: .trueNorth)),
            source: .init(providerID: replacement.id), receivedAt: .init(nanoseconds: 1)))
        let states = await controlled.allProviderStates()
        let registrations = await controlled.providerRegistrations()
        let observations = await controlled.allCandidates(for: .navigationHeading)
        #expect(registrations[replacement.id] != originalRegistrations[replacement.id])
        await clock.release()
        await operation.value
        #expect(vector.expected == "stateAndRegistrationsUnchangedAfterOldCompletion")
        #expect(await controlled.allProviderStates() == states, "vector: \(vector.id)")
        #expect(await controlled.providerRegistrations() == registrations, "vector: \(vector.id)")
        #expect(await controlled.allCandidates(for: .navigationHeading) == observations, "vector: \(vector.id)")
    }
}

private actor RegistrationClock: VesselLayerClock {
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
