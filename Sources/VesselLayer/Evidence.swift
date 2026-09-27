import Foundation

public enum QualificationLevel: String, Codable, Sendable {
    case declared, observed, replayValidated, vesselReadValidated, vesselControlValidated, revoked
}

public struct QualificationEvidence: Hashable, Codable, Sendable {
    public var id: EvidenceID
    public var providerID: ProviderID
    public var vesselID: VesselID?
    public var assetID: AssetID?
    public var capabilityID: CapabilityID?
    public var observationID: ObservationID?
    public var operationID: OperationID?
    public var level: QualificationLevel
    public var implementationVersion: String
    public var recordedAt: Date
    public var reference: String
    public init(id: EvidenceID, providerID: ProviderID, vesselID: VesselID? = nil,
                assetID: AssetID? = nil, capabilityID: CapabilityID? = nil,
                observationID: ObservationID? = nil, operationID: OperationID? = nil,
                level: QualificationLevel,
                implementationVersion: String, recordedAt: Date, reference: String) {
        self.id = id; self.providerID = providerID; self.vesselID = vesselID; self.assetID = assetID
        self.capabilityID = capabilityID; self.observationID = observationID; self.operationID = operationID
        self.level = level; self.implementationVersion = implementationVersion; self.recordedAt = recordedAt; self.reference = reference
    }
}

/// Contract-only representation. HB-001A does not dispatch commands.
public enum CommandOutcome: Hashable, Codable, Sendable {
    case accepted
    case acknowledged
    case completed
    case rejected(reason: String)
    case unsupported
    case timedOut
    case cancelled
    case uncertain(retrySafe: Bool, detail: String?)
}
