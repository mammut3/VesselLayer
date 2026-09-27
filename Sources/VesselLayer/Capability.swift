public enum CapabilityKind: Hashable, Sendable {
    case observation(ObservationID)
    case operation(OperationID)
}

extension CapabilityKind: Codable {
    private enum CodingKeys: String, CodingKey { case type, id }
    private enum Kind: String, Codable { case observation, operation }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .observation:
            self = .observation(try container.decode(ObservationID.self, forKey: .id))
        case .operation:
            self = .operation(try container.decode(OperationID.self, forKey: .id))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .observation(let id):
            try container.encode(Kind.observation, forKey: .type)
            try container.encode(id, forKey: .id)
        case .operation(let id):
            try container.encode(Kind.operation, forKey: .type)
            try container.encode(id, forKey: .id)
        }
    }
}

/// Capability availability is not a qualification or authorization decision.
public enum CapabilityAvailability: String, Codable, Sendable {
    case available
    case unavailable
    case potential
    case unqualified
    case ambiguous
}

public struct CapabilityState: Hashable, Codable, Sendable {
    public var id: CapabilityID
    public var kind: CapabilityKind
    public var availability: CapabilityAvailability
    public var providerIDs: [ProviderID]
    public var evidenceIDs: [EvidenceID]
    public var reason: String

    public init(id: CapabilityID, kind: CapabilityKind, availability: CapabilityAvailability,
                providerIDs: [ProviderID] = [], evidenceIDs: [EvidenceID] = [], reason: String) {
        self.id = id
        self.kind = kind
        self.availability = availability
        self.providerIDs = Array(Set(providerIDs)).sorted()
        self.evidenceIDs = Array(Set(evidenceIDs)).sorted()
        self.reason = reason
    }
}

public enum ProviderMatchState: String, Codable, Sendable {
    case candidate
    case matched
    case needsConfirmation
    case rejected
}

public struct EvidenceReference: Hashable, Codable, Sendable {
    public var id: EvidenceID
    public var kind: String
    public var summary: String
    public var attributes: [String: String]

    public init(id: EvidenceID, kind: String, summary: String,
                attributes: [String: String] = [:]) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.attributes = attributes
    }
}

/// Explainable adapter-supplied matching result. Core does not assign a confidence score.
public struct ProviderMatch: Hashable, Codable, Sendable {
    public var providerID: ProviderID
    public var assetID: AssetID
    public var state: ProviderMatchState
    public var evidence: [EvidenceReference]
    public var explanation: String

    public init(providerID: ProviderID, assetID: AssetID, state: ProviderMatchState,
                evidence: [EvidenceReference], explanation: String) {
        self.providerID = providerID
        self.assetID = assetID
        self.state = state
        self.evidence = evidence.sorted { $0.id < $1.id }
        self.explanation = explanation
    }
}
