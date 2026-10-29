import Foundation
import Testing
import VesselLayerTesting
@testable import VesselLayer

@Suite("Ordered field validity evidence")
struct ValidityEvidenceTests {
    let descriptor = TestProviders.descriptor("sensor")
    let policy = ReadAuthorityPolicy(freshness: .init(freshForNanoseconds: 1_000))
    func sample(_ provider: ProviderID, at: UInt64, stream: String = "a") -> AnyObservation {
        .init(id: .navigationHeading, value: .heading(.init(radians: 1, reference: .trueNorth)),
              source: .init(providerID: provider, attributes: ["stream": stream, "receipt": String(at)]), receivedAt: .init(nanoseconds: at))
    }
    @Test func publicStreamValidityOwnershipVectors() async throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../fixtures/conformance/0.1.0/stream-validity-ownership.json")
            .standardizedFileURL
        let file = try JSONDecoder().decode(StreamValidityVectors.self, from: Data(contentsOf: url))
        #expect(file.schemaVersion == "0.1.0")
        for vector in file.vectors {
            let store = VesselObservationStore(clock: ManualClock())
            await store.register(descriptor)
            await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
            await store.ingest(sample(descriptor.id, at: 10, stream: "a"))
            await store.ingest(sample(descriptor.id, at: 20, stream: "b"))
            let provisional = TestProviders.descriptor("provisional")
            if vector.reconcile { await store.register(provisional) }
            let negativeProvider = vector.reconcile ? provisional.id : descriptor.id
            if vector.negativeAfterOther {
                #expect(await store.ingest(sample(descriptor.id, at: vector.otherAt, stream: "b")))
            }
            #expect(await store.invalidate(.navigationHeading,
                from: sample(negativeProvider, at: vector.negativeAt, stream: "a").source,
                at: .init(nanoseconds: vector.negativeAt), matchingAttributes: ["stream": "a"]), "vector: \(vector.id)")
            if !vector.negativeAfterOther {
                #expect(await store.ingest(sample(descriptor.id, at: vector.otherAt, stream: "b")))
            }
            if vector.reconcile { await store.reconcileProvider(from: provisional.id, to: descriptor) }
            #expect(await store.ingest(sample(descriptor.id, at: vector.delayedAt, stream: "a")) == false, "vector: \(vector.id)")
            let current = try #require(await store.allCandidates(for: .navigationHeading).first)
            #expect(current.source.attributes["stream"] == "b" && current.validity == .valid, "vector: \(vector.id)")
            #expect(current.receivedAt.nanoseconds == vector.otherAt, "vector: \(vector.id)")
            // Inspect retained scope via the public closed-stream cleanup contract.
            #expect(await store.discardInvalidations(for: descriptor.id, matchingAttributes: ["stream": "a"]) == 1, "vector: \(vector.id)")
            // Re-establish that same negative-only stream before testing recovery.
            #expect(await store.invalidate(.navigationHeading,
                from: sample(descriptor.id, at: vector.negativeAt, stream: "a").source,
                at: .init(nanoseconds: vector.negativeAt), matchingAttributes: ["stream": "a"]))
            let recoveryAt = max(vector.negativeAt, vector.otherAt) + 1
            #expect(await store.ingest(sample(descriptor.id, at: recoveryAt, stream: "a")))
            #expect(await store.discardInvalidations(for: descriptor.id, matchingAttributes: ["stream": "a"]) == 0)
        }
    }

    @Test func negativesAreStrictlyOrderedAndKeepLastMeasurement() async throws {
        let store = VesselObservationStore(clock: ManualClock())
        await store.register(descriptor)
        await store.updateProvider(descriptor.id, lifecycle: .present, health: .healthy)
        let valid = sample(descriptor.id, at: 20)
        await store.ingest(valid)
        for stamp in [19, 20] {
            #expect(await store.invalidate(.navigationHeading, from: valid.source, at: .init(nanoseconds: UInt64(stamp)), matchingAttributes: ["stream": "a"]) == false)
        }
        #expect(await store.invalidate(.navigationHeading, from: valid.source, at: .init(nanoseconds: 21), matchingAttributes: ["stream": "b"]) == false)
        #expect(await store.invalidate(.navigationHeading, from: valid.source, at: .init(nanoseconds: 21), matchingAttributes: ["stream": "a"]))
        let invalid = try #require(await store.allCandidates(for: .navigationHeading).first)
        #expect(invalid.receivedAt == valid.receivedAt && invalid.value == valid.value && invalid.source == valid.source)
        #expect(invalid.validity == .unavailable)
        #expect(await store.authority(for: .navigationHeading, policy: policy).observation == nil)
        #expect(await store.ingest(sample(descriptor.id, at: 21)) == false)
        #expect(await store.ingest(sample(descriptor.id, at: 22)))
        #expect(await store.authority(for: .navigationHeading, policy: policy).observation?.receivedAt.nanoseconds == 22)
    }
    @Test func invalidFirstMigratesAndRemovalClearsWatermark() async {
        let store = VesselObservationStore(clock: ManualClock())
        await store.register(descriptor)
        let source = sample(descriptor.id, at: 20).source
        #expect(await store.invalidate(.navigationHeading, from: source, at: .init(nanoseconds: 20), matchingAttributes: ["stream": "a"]))
        let durable = TestProviders.descriptor("durable")
        await store.reconcileProvider(from: descriptor.id, to: durable)
        #expect(await store.ingest(sample(durable.id, at: 19)) == false)
        #expect(await store.ingest(sample(durable.id, at: 21)))
        await store.removeProvider(durable.id)
        await store.register(durable)
        #expect(await store.ingest(sample(durable.id, at: 1)))
    }
    @Test func foreignNegativeCannotInvalidateDurableStreamDuringReconciliation() async {
        let store = VesselObservationStore(clock: ManualClock())
        let durable = TestProviders.descriptor("durable")
        await store.register(descriptor); await store.register(durable)
        await store.ingest(sample(durable.id, at: 10, stream: "b"))
        await store.invalidate(.navigationHeading, from: sample(descriptor.id, at: 20).source,
                               at: .init(nanoseconds: 20), matchingAttributes: ["stream": "a"])
        await store.reconcileProvider(from: descriptor.id, to: durable)
        #expect(await store.allCandidates(for: .navigationHeading).first?.validity == .valid)
        #expect(await store.ingest(sample(durable.id, at: 11, stream: "b")))
    }
    @Test func lateIdentityHandoverKeepsForeignStreamNegativeWithoutRetiringCurrentStream() async {
        let store = VesselObservationStore(clock: ManualClock())
        let durable = TestProviders.descriptor("durable")
        await store.register(descriptor); await store.register(durable)
        let old = sample(durable.id, at: 10, stream: "a")
        await store.ingest(old)
        await store.invalidate(.navigationHeading, from: sample(descriptor.id, at: 22, stream: "b").source,
                               at: .init(nanoseconds: 22), matchingAttributes: ["stream": "b"])
        await store.reconcileProvider(from: descriptor.id, to: durable)
        #expect(await store.allCandidates(for: .navigationHeading).first?.validity == .valid)
        await store.invalidate(.navigationHeading, from: old.source, at: .init(nanoseconds: 23), matchingAttributes: ["stream": "a"])
        #expect(await store.ingest(sample(durable.id, at: 21, stream: "b")) == false)
        #expect(await store.ingest(sample(durable.id, at: 24, stream: "b")))
    }

    @Test func closedStreamCleanupKeepsRetiredDiagnosticsAndOtherBoundaries() async {
        let store = VesselObservationStore(clock: ManualClock())
        await store.register(descriptor)
        let old = sample(descriptor.id, at: 10)
        await store.ingest(old)
        await store.invalidate(.navigationHeading, from: old.source, at: .init(nanoseconds: 20), matchingAttributes: ["stream": "a"])
        await store.invalidate(.navigationHeading, from: sample(descriptor.id, at: 22, stream: "b").source,
                               at: .init(nanoseconds: 22), matchingAttributes: ["stream": "b"])
        #expect(await store.discardInvalidations(for: descriptor.id, matchingAttributes: ["stream": "a"]) == 1)
        #expect(await store.allCandidates(for: .navigationHeading).first?.validity == .unavailable)
        #expect(await store.ingest(sample(descriptor.id, at: 21, stream: "b")) == false)
        #expect(await store.discardInvalidations(for: descriptor.id, matchingAttributes: ["stream": "a"]) == 0)
    }

    @Test func repeatedRetirementCannotReplaceNewStreamNegativeBoundary() async {
        let store = VesselObservationStore(clock: ManualClock())
        await store.register(descriptor)
        let old = sample(descriptor.id, at: 10)
        await store.ingest(old)
        await store.invalidate(.navigationHeading, from: old.source, at: nil, matchingAttributes: ["stream": "a"])
        await store.invalidate(.navigationHeading, from: sample(descriptor.id, at: 22, stream: "b").source,
                               at: .init(nanoseconds: 22), matchingAttributes: ["stream": "b"])
        #expect(await store.invalidate(.navigationHeading, from: old.source, at: nil, matchingAttributes: ["stream": "a"]) == false)
        #expect(await store.ingest(sample(descriptor.id, at: 21, stream: "b")) == false)
        #expect(await store.ingest(sample(descriptor.id, at: 23, stream: "b")))
    }

    @Test func lifecycleRetirementCannotRetireMeasurementPublishedAfterCapture() async {
        let store = VesselObservationStore(clock: ManualClock())
        await store.register(descriptor)
        let captured = sample(descriptor.id, at: 10)
        await store.ingest(captured)
        await store.ingest(sample(descriptor.id, at: 11))
        #expect(await store.invalidate(.navigationHeading, from: captured.source, at: nil, matchingAttributes: ["stream": "a"]) == false)
        let current = sample(descriptor.id, at: 11)
        #expect(await store.invalidate(.navigationHeading, from: current.source, at: nil, matchingAttributes: ["stream": "a"]))
        #expect(await store.ingest(current) == false)
        #expect(await store.ingest(sample(descriptor.id, at: 12)))
    }
}

private struct StreamValidityVectors: Decodable {
    let schemaVersion: String
    let vectors: [StreamValidityVector]
}
private struct StreamValidityVector: Decodable {
    let id: String
    let negativeAt: UInt64
    let otherAt: UInt64
    let delayedAt: UInt64
    let negativeAfterOther: Bool
    let reconcile: Bool
}
