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
