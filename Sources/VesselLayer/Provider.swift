public enum ProviderLifecycle: String, Codable, Sendable {
    case registered
    case present
    case unavailable
    case withdrawn
}

public enum ProviderHealth: String, Codable, Sendable { case healthy, degraded, unhealthy, unknown }
public enum ProviderAvailability: String, Codable, Sendable { case available, unavailable, withdrawn }

public struct ProviderDescriptor: Hashable, Codable, Sendable {
    public var id: ProviderID
    public var vesselID: VesselID
    public var assetID: AssetID?
    public var label: String
    public init(id: ProviderID, vesselID: VesselID, assetID: AssetID? = nil, label: String) {
        self.id = id; self.vesselID = vesselID; self.assetID = assetID; self.label = label
    }
}

public struct ProviderState: Hashable, Codable, Sendable {
    public var descriptor: ProviderDescriptor
    public var lifecycle: ProviderLifecycle
    public var health: ProviderHealth
    public var updatedAt: MonotonicInstant
    public init(descriptor: ProviderDescriptor, lifecycle: ProviderLifecycle = .registered,
                health: ProviderHealth = .unknown, updatedAt: MonotonicInstant) {
        self.descriptor = descriptor; self.lifecycle = lifecycle; self.health = health; self.updatedAt = updatedAt
    }
    public var availability: ProviderAvailability {
        if lifecycle == .withdrawn { return .withdrawn }
        if lifecycle == .present && (health == .healthy || health == .degraded) { return .available }
        return .unavailable
    }
}
