import Foundation
import Testing
@testable import VesselLayer
import VesselLayerTesting

private struct VectorFile: Decodable { let schemaVersion: String; let vectors: [Vector] }
private struct Vector: Decodable {
    let id: String
    let events: [Event]
    let policy: Policy
    let expectedProviderID: String?
    let expectedReason: String
}
private struct Event: Decodable { let type: String; let providerID: String?; let targetProviderID: String?; let seconds: UInt64?; let value: Double? }
private struct Policy: Decodable { let freshForSeconds: UInt64; let providerRanks: [String: Int] }

@Test func publicTechnologyNeutralAuthorityVectors() async throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../fixtures/conformance/0.1.0/read-authority.json")
        .standardizedFileURL
    let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
    #expect(file.schemaVersion == "0.1.0")
    for vector in file.vectors {
        let clock = ManualClock(); let store = VesselObservationStore(clock: clock)
        for event in vector.events {
            guard let rawID = event.providerID else {
                if event.type == "advance" { await clock.advance(by: .seconds(event.seconds ?? 0)) }
                continue
            }
            let id = ProviderID(rawValue: rawID)
            switch event.type {
            case "register": _ = await store.register(TestProviders.descriptor(rawID))
            case "present": await store.updateProvider(id, lifecycle: .present, health: .healthy)
            case "unavailable": await store.updateProvider(id, lifecycle: .unavailable, health: .unhealthy)
            case "withdraw": await store.withdrawProvider(id)
            case "remove": await store.removeProvider(id)
            case "reconcile":
                let target = event.targetProviderID ?? ""
                await store.reconcileProvider(from: id, to: TestProviders.descriptor(target))
            case "observe":
                await store.ingest(AnyObservation(id: .navigationHeading,
                    value: .heading(.init(radians: event.value ?? 0, reference: .trueNorth)),
                    source: .init(providerID: id), receivedAt: await clock.now()))
            default: Issue.record("Unknown event \(event.type)")
            }
        }
        let ranks = Dictionary(uniqueKeysWithValues: vector.policy.providerRanks.map { (ProviderID(rawValue: $0.key), $0.value) })
        let decision = await store.authority(for: .navigationHeading,
            policy: .init(providerRanks: ranks, freshness: .init(freshForNanoseconds: vector.policy.freshForSeconds * 1_000_000_000)))
        #expect(decision.observation?.source.providerID.rawValue == vector.expectedProviderID, "vector: \(vector.id)")
        let reason: String
        switch decision.reason {
        case .selectedOnlyEligibleCandidate: reason = "onlyEligible"
        case .selectedByPolicyRank: reason = "policyRank"
        case .selectedByQuality: reason = "quality"
        case .selectedByStableProviderID: reason = "stableProviderID"
        case .noRegisteredCandidates: reason = "noRegisteredCandidates"
        case .noEligibleCandidates: reason = "noEligibleCandidates"
        }
        #expect(reason == vector.expectedReason, "vector: \(vector.id)")
    }
}
