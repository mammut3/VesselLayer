public protocol VesselLayerIdentifier: RawRepresentable, Hashable, Codable, Sendable, Comparable
where RawValue == String {
    init(rawValue: String)
}

public extension VesselLayerIdentifier {
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct VesselID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct AssetID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ProviderID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct ObservationID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct EvidenceID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct OperationID: VesselLayerIdentifier { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }

public extension ObservationID {
    static let navigationPosition = Self(rawValue: "navigation.position")
    static let navigationHeading = Self(rawValue: "navigation.heading")
    static let navigationCourseOverGround = Self(rawValue: "navigation.courseOverGround")
    static let navigationSpeedOverGround = Self(rawValue: "navigation.speedOverGround")
}
