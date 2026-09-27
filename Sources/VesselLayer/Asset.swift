public enum AssetPresence: String, Codable, Sendable {
    case unknown
    case present
    case missing
}

public enum AssetHealth: String, Codable, Sendable {
    case healthy
    case degraded
    case unhealthy
    case unknown
}

/// Identity state is deliberately independent from presence and health. An AssetID is an
/// inventory record key; it must not be treated as durable while identity remains partial.
/// Transport adapters decide when their evidence justifies a durable association.
public enum AssetIdentityState: String, Codable, Sendable {
    case partial
    case identified
    case ambiguous
    case conflicting
}

/// A transport-neutral description of an observed logical or physical vessel component.
/// `attributes` may contain bounded, non-sensitive adapter evidence; protocol identities stay
/// in the adapter and must not be promoted to generic fields.
public struct AssetDescriptor: Hashable, Codable, Sendable {
    public var id: AssetID
    public var vesselID: VesselID
    public var label: String?
    public var manufacturer: String?
    public var model: String?
    public var productIdentifier: String?
    public var softwareVersion: String?
    public var roles: [String]
    public var attributes: [String: String]

    public init(id: AssetID, vesselID: VesselID, label: String? = nil,
                manufacturer: String? = nil, model: String? = nil,
                productIdentifier: String? = nil, softwareVersion: String? = nil,
                roles: [String] = [], attributes: [String: String] = [:]) {
        self.id = id
        self.vesselID = vesselID
        self.label = label
        self.manufacturer = manufacturer
        self.model = model
        self.productIdentifier = productIdentifier
        self.softwareVersion = softwareVersion
        self.roles = Array(Set(roles)).sorted()
        self.attributes = attributes
    }
}

public struct AssetState: Hashable, Codable, Sendable {
    public var descriptor: AssetDescriptor
    public var presence: AssetPresence
    public var health: AssetHealth
    public var identityState: AssetIdentityState
    public var firstSeenAt: MonotonicInstant
    public var lastSeenAt: MonotonicInstant
    public var updatedAt: MonotonicInstant
    public var evidenceIDs: [EvidenceID]

    public init(descriptor: AssetDescriptor, presence: AssetPresence = .present,
                health: AssetHealth = .unknown, identityState: AssetIdentityState,
                firstSeenAt: MonotonicInstant, lastSeenAt: MonotonicInstant,
                updatedAt: MonotonicInstant? = nil,
                evidenceIDs: [EvidenceID] = []) {
        self.descriptor = descriptor
        self.presence = presence
        self.health = health
        self.identityState = identityState
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.updatedAt = updatedAt ?? lastSeenAt
        self.evidenceIDs = Array(Set(evidenceIDs)).sorted()
    }
}

public enum AssetChange: String, Codable, Sendable {
    case new
    case observed
    case changed
    case missing
    case reappeared
    case ambiguous
    case conflicting
}

public struct AssetUpdate: Hashable, Codable, Sendable {
    public var state: AssetState
    public var change: AssetChange
    public init(state: AssetState, change: AssetChange) {
        self.state = state
        self.change = change
    }
}

/// Small in-memory reference inventory. Identity reconciliation remains adapter policy.
public actor AssetInventory {
    private var states: [AssetID: AssetState] = [:]

    public init() {}

    @discardableResult
    public func observe(_ descriptor: AssetDescriptor, at instant: MonotonicInstant,
                        health: AssetHealth = .unknown,
                        identityState: AssetIdentityState,
                        evidenceIDs: [EvidenceID] = []) -> AssetUpdate {
        guard var existing = states[descriptor.id] else {
            let state = AssetState(descriptor: descriptor, health: health,
                                   identityState: identityState, firstSeenAt: instant,
                                   lastSeenAt: instant, evidenceIDs: Array(Set(evidenceIDs)).sorted())
            states[descriptor.id] = state
            return AssetUpdate(state: state, change: change(for: identityState, fallback: .new))
        }

        let reappeared = existing.presence == .missing
        let normalizedEvidenceIDs = Array(Set(evidenceIDs)).sorted()
        let changed = existing.descriptor != descriptor || existing.health != health ||
            existing.identityState != identityState || existing.evidenceIDs != normalizedEvidenceIDs
        existing.descriptor = descriptor
        existing.presence = .present
        existing.health = health
        existing.identityState = identityState
        existing.lastSeenAt = max(existing.lastSeenAt, instant)
        existing.updatedAt = max(existing.updatedAt, instant)
        existing.evidenceIDs = normalizedEvidenceIDs
        states[descriptor.id] = existing

        let fallback: AssetChange = reappeared ? .reappeared : (changed ? .changed : .observed)
        return AssetUpdate(state: existing, change: change(for: identityState, fallback: fallback))
    }

    @discardableResult
    public func markMissing(_ id: AssetID, at instant: MonotonicInstant) -> AssetUpdate? {
        guard var existing = states[id] else { return nil }
        existing.presence = .missing
        existing.updatedAt = max(existing.updatedAt, instant)
        states[id] = existing
        return AssetUpdate(state: existing, change: .missing)
    }

    public func state(for id: AssetID) -> AssetState? { states[id] }

    public func allStates() -> [AssetState] {
        states.values.sorted { $0.descriptor.id < $1.descriptor.id }
    }

    private func change(for identityState: AssetIdentityState, fallback: AssetChange) -> AssetChange {
        switch identityState {
        case .ambiguous: return .ambiguous
        case .conflicting: return .conflicting
        case .partial, .identified: return fallback
        }
    }
}
