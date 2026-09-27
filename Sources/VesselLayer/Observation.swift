import Foundation

public enum ObservationValidity: String, Codable, Sendable { case valid, invalid, unavailable }

public struct ObservationQuality: Hashable, Codable, Sendable {
    public var confidence: Double?
    public var horizontalAccuracyMeters: Double?
    public var metadata: [String: String]
    public init(confidence: Double? = nil, horizontalAccuracyMeters: Double? = nil, metadata: [String: String] = [:]) {
        self.confidence = confidence
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.metadata = metadata
    }
}

public struct ObservationSource: Hashable, Codable, Sendable {
    public var providerID: ProviderID
    public var assetID: AssetID?
    public var attributes: [String: String]
    public init(providerID: ProviderID, assetID: AssetID? = nil, attributes: [String: String] = [:]) {
        self.providerID = providerID
        self.assetID = assetID
        self.attributes = attributes
    }
}

public struct GeographicPosition: Hashable, Codable, Sendable {
    public var latitudeDegrees: Double
    public var longitudeDegrees: Double
    public init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.latitudeDegrees = latitudeDegrees
        self.longitudeDegrees = longitudeDegrees
    }
}

public enum HeadingReference: String, Codable, Sendable { case trueNorth, magneticNorth }
public struct Heading: Hashable, Codable, Sendable {
    public var radians: Double
    public var reference: HeadingReference
    public init(radians: Double, reference: HeadingReference) { self.radians = radians; self.reference = reference }
}

public enum ObservationValue: Hashable, Codable, Sendable {
    case position(GeographicPosition)
    case heading(Heading)
    case courseOverGroundRadians(Double)
    case speedOverGroundMetersPerSecond(Double)
}

public struct Observation<Value: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    public var id: ObservationID
    public var value: Value
    public var source: ObservationSource
    public var observedAt: Date?
    public var receivedAt: MonotonicInstant
    public var validity: ObservationValidity
    public var quality: ObservationQuality?
    public init(id: ObservationID, value: Value, source: ObservationSource, observedAt: Date? = nil,
                receivedAt: MonotonicInstant, validity: ObservationValidity = .valid, quality: ObservationQuality? = nil) {
        self.id = id; self.value = value; self.source = source; self.observedAt = observedAt
        self.receivedAt = receivedAt; self.validity = validity; self.quality = quality
    }
}

public typealias AnyObservation = Observation<ObservationValue>

public extension Observation {
    func freshness(at now: MonotonicInstant, policy: FreshnessPolicy) -> FreshnessState {
        guard now.nanoseconds >= receivedAt.nanoseconds else { return .fresh }
        return now.nanoseconds - receivedAt.nanoseconds <= policy.freshForNanoseconds ? .fresh : .stale
    }
}
