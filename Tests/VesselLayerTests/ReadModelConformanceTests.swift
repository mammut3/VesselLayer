import Foundation
import Testing
@testable import VesselLayer

private struct ReadModelVectorFile: Decodable {
    let schemaVersion: String
    let vectors: [ReadModelVector]
}

private struct ReadModelVector: Decodable {
    let id: String
    let events: [ReadModelEvent]
    let expected: ReadModelExpected
}

private struct ReadModelEvent: Decodable {
    let type: String
    let at: UInt64
    let manufacturer: String?
}

private struct ReadModelExpected: Decodable {
    let changes: [String]
    let presence: String
    let identityState: String
    let firstSeenAt: UInt64
    let lastSeenAt: UInt64
    let updatedAt: UInt64
    let manufacturer: String?
}

@Test func publicTechnologyNeutralAssetLifecycleVectors() async throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../fixtures/conformance/0.1.0/read-model.json")
        .standardizedFileURL
    let file = try JSONDecoder().decode(ReadModelVectorFile.self, from: Data(contentsOf: url))
    #expect(file.schemaVersion == "0.1.0")

    for vector in file.vectors {
        let inventory = AssetInventory()
        let id = AssetID(rawValue: "synthetic-asset")
        let vesselID = VesselID(rawValue: "synthetic-vessel")
        var changes: [String] = []
        for event in vector.events {
            let instant = MonotonicInstant(nanoseconds: event.at)
            let update: AssetUpdate?
            switch event.type {
            case "observePartial":
                update = await inventory.observe(
                    AssetDescriptor(id: id, vesselID: vesselID), at: instant,
                    identityState: .partial)
            case "observeIdentified":
                update = await inventory.observe(
                    AssetDescriptor(id: id, vesselID: vesselID,
                                    manufacturer: event.manufacturer), at: instant,
                    health: .healthy, identityState: .identified)
            case "observeAmbiguous":
                update = await inventory.observe(
                    AssetDescriptor(id: id, vesselID: vesselID), at: instant,
                    identityState: .ambiguous,
                    evidenceIDs: [.init(rawValue: "identity-a"), .init(rawValue: "identity-b")])
            case "observeConflicting":
                update = await inventory.observe(
                    AssetDescriptor(id: id, vesselID: vesselID), at: instant,
                    identityState: .conflicting,
                    evidenceIDs: [.init(rawValue: "identity-a"), .init(rawValue: "identity-b")])
            case "markMissing":
                update = await inventory.markMissing(id, at: instant)
            default:
                Issue.record("Unknown event \(event.type) in vector \(vector.id)")
                update = nil
            }
            if let update { changes.append(update.change.rawValue) }
        }

        let state = await inventory.state(for: id)
        #expect(changes == vector.expected.changes, "vector: \(vector.id)")
        #expect(state?.presence.rawValue == vector.expected.presence, "vector: \(vector.id)")
        #expect(state?.identityState.rawValue == vector.expected.identityState, "vector: \(vector.id)")
        #expect(state?.firstSeenAt.nanoseconds == vector.expected.firstSeenAt, "vector: \(vector.id)")
        #expect(state?.lastSeenAt.nanoseconds == vector.expected.lastSeenAt, "vector: \(vector.id)")
        #expect(state?.updatedAt.nanoseconds == vector.expected.updatedAt, "vector: \(vector.id)")
        #expect(state?.descriptor.manufacturer == vector.expected.manufacturer, "vector: \(vector.id)")
    }
}
