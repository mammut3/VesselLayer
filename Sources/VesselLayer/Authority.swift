public struct ReadAuthorityPolicy: Hashable, Codable, Sendable {
    /// Lower values are preferred. Unlisted providers share the default rank.
    public var providerRanks: [ProviderID: Int]
    public var defaultRank: Int
    public var freshness: FreshnessPolicy
    public init(providerRanks: [ProviderID: Int] = [:], defaultRank: Int = 1_000,
                freshness: FreshnessPolicy) {
        self.providerRanks = providerRanks; self.defaultRank = defaultRank; self.freshness = freshness
    }
}

public enum AuthorityReason: Hashable, Sendable {
    case selectedOnlyEligibleCandidate
    case selectedByPolicyRank(rank: Int)
    case selectedByQuality
    case selectedByStableProviderID
    case noRegisteredCandidates
    case noEligibleCandidates
}

extension AuthorityReason: Codable {
    private enum CodingKeys: String, CodingKey { case type, rank }
    private enum Kind: String, Codable {
        case selectedOnlyEligibleCandidate
        case selectedByPolicyRank
        case selectedByQuality
        case selectedByStableProviderID
        case noRegisteredCandidates
        case noEligibleCandidates
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .selectedOnlyEligibleCandidate: self = .selectedOnlyEligibleCandidate
        case .selectedByPolicyRank:
            self = .selectedByPolicyRank(rank: try container.decode(Int.self, forKey: .rank))
        case .selectedByQuality: self = .selectedByQuality
        case .selectedByStableProviderID: self = .selectedByStableProviderID
        case .noRegisteredCandidates: self = .noRegisteredCandidates
        case .noEligibleCandidates: self = .noEligibleCandidates
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .selectedOnlyEligibleCandidate:
            try container.encode(Kind.selectedOnlyEligibleCandidate, forKey: .type)
        case .selectedByPolicyRank(let rank):
            try container.encode(Kind.selectedByPolicyRank, forKey: .type)
            try container.encode(rank, forKey: .rank)
        case .selectedByQuality:
            try container.encode(Kind.selectedByQuality, forKey: .type)
        case .selectedByStableProviderID:
            try container.encode(Kind.selectedByStableProviderID, forKey: .type)
        case .noRegisteredCandidates:
            try container.encode(Kind.noRegisteredCandidates, forKey: .type)
        case .noEligibleCandidates:
            try container.encode(Kind.noEligibleCandidates, forKey: .type)
        }
    }
}

public struct AuthorityDecision: Hashable, Codable, Sendable {
    public var observation: AnyObservation?
    public var reason: AuthorityReason
    public var eligibleProviderIDs: [ProviderID]
    public init(observation: AnyObservation?, reason: AuthorityReason, eligibleProviderIDs: [ProviderID]) {
        self.observation = observation; self.reason = reason; self.eligibleProviderIDs = eligibleProviderIDs
    }
}

public struct SourceCandidate: Hashable, Codable, Sendable {
    public var observation: AnyObservation
    public var providerLifecycle: ProviderLifecycle
    public var providerHealth: ProviderHealth
    public var providerAvailability: ProviderAvailability
    public var freshness: FreshnessState
    public var isAuthoritative: Bool
    public var authorityReason: AuthorityReason?

    public init(observation: AnyObservation, providerLifecycle: ProviderLifecycle,
                providerHealth: ProviderHealth, providerAvailability: ProviderAvailability,
                freshness: FreshnessState, isAuthoritative: Bool,
                authorityReason: AuthorityReason? = nil) {
        self.observation = observation
        self.providerLifecycle = providerLifecycle
        self.providerHealth = providerHealth
        self.providerAvailability = providerAvailability
        self.freshness = freshness
        self.isAuthoritative = isAuthoritative
        self.authorityReason = authorityReason
    }
}

public struct DataSourceMapEntry: Hashable, Codable, Sendable {
    public var observationID: ObservationID
    public var candidates: [SourceCandidate]
    public var authorityReason: AuthorityReason

    public init(observationID: ObservationID, candidates: [SourceCandidate],
                authorityReason: AuthorityReason) {
        self.observationID = observationID
        self.candidates = candidates.sorted { $0.observation.source.providerID < $1.observation.source.providerID }
        self.authorityReason = authorityReason
    }
}

public actor VesselObservationStore {
    private let clock: any VesselLayerClock
    private var providers: [ProviderID: ProviderState] = [:]
    private var candidates: [ObservationID: [ProviderID: AnyObservation]] = [:]

    public init(clock: any VesselLayerClock) { self.clock = clock }

    @discardableResult public func register(_ descriptor: ProviderDescriptor) async -> ProviderState {
        if let existing = providers[descriptor.id] { return existing }
        let state = ProviderState(descriptor: descriptor, updatedAt: await clock.now())
        providers[descriptor.id] = state
        return state
    }

    public func updateProvider(_ id: ProviderID, lifecycle: ProviderLifecycle, health: ProviderHealth) async {
        guard var state = providers[id], state.lifecycle != .withdrawn else { return }
        state.lifecycle = lifecycle; state.health = health; state.updatedAt = await clock.now(); providers[id] = state
    }

    public func withdrawProvider(_ id: ProviderID) async {
        guard var state = providers[id] else { return }
        state.lifecycle = .withdrawn; state.updatedAt = await clock.now(); providers[id] = state
    }

    public func providerState(_ id: ProviderID) -> ProviderState? { providers[id] }

    public func allProviderStates() -> [ProviderState] {
        providers.values.sorted { $0.descriptor.id < $1.descriptor.id }
    }

    public func ingest(_ observation: AnyObservation) {
        guard providers[observation.source.providerID] != nil else { return }
        candidates[observation.id, default: [:]][observation.source.providerID] = observation
    }

    public func allCandidates(for id: ObservationID) -> [AnyObservation] {
        Array(candidates[id, default: [:]].values).sorted { $0.source.providerID < $1.source.providerID }
    }

    public func authority(for id: ObservationID, policy: ReadAuthorityPolicy) async -> AuthorityDecision {
        guard let registered = candidates[id], !registered.isEmpty else {
            return AuthorityDecision(observation: nil, reason: .noRegisteredCandidates, eligibleProviderIDs: [])
        }
        let now = await clock.now()
        let eligible = registered.values.filter { observation in
            guard observation.validity == .valid,
                  observation.freshness(at: now, policy: policy.freshness) == .fresh,
                  let provider = providers[observation.source.providerID]
            else { return false }
            return provider.availability == .available
        }
        guard !eligible.isEmpty else {
            return AuthorityDecision(observation: nil, reason: .noEligibleCandidates, eligibleProviderIDs: [])
        }
        let sorted = eligible.sorted { lhs, rhs in
            let lhsRank = policy.providerRanks[lhs.source.providerID] ?? policy.defaultRank
            let rhsRank = policy.providerRanks[rhs.source.providerID] ?? policy.defaultRank
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            let lhsQuality = lhs.quality?.confidence ?? -1
            let rhsQuality = rhs.quality?.confidence ?? -1
            if lhsQuality != rhsQuality { return lhsQuality > rhsQuality }
            return lhs.source.providerID < rhs.source.providerID
        }
        let winner = sorted[0]
        let ids = sorted.map(\.source.providerID)
        if sorted.count == 1 { return AuthorityDecision(observation: winner, reason: .selectedOnlyEligibleCandidate, eligibleProviderIDs: ids) }
        let winnerRank = policy.providerRanks[winner.source.providerID] ?? policy.defaultRank
        let runnerRank = policy.providerRanks[sorted[1].source.providerID] ?? policy.defaultRank
        if winnerRank != runnerRank { return AuthorityDecision(observation: winner, reason: .selectedByPolicyRank(rank: winnerRank), eligibleProviderIDs: ids) }
        if (winner.quality?.confidence ?? -1) != (sorted[1].quality?.confidence ?? -1) {
            return AuthorityDecision(observation: winner, reason: .selectedByQuality, eligibleProviderIDs: ids)
        }
        return AuthorityDecision(observation: winner, reason: .selectedByStableProviderID, eligibleProviderIDs: ids)
    }

    public func sourceMapEntry(for id: ObservationID,
                               policy: ReadAuthorityPolicy) async -> DataSourceMapEntry {
        let decision = await authority(for: id, policy: policy)
        let authoritativeID = decision.observation?.source.providerID
        let now = await clock.now()
        let sourceCandidates = candidates[id, default: [:]].values.compactMap { observation -> SourceCandidate? in
            guard let provider = providers[observation.source.providerID] else { return nil }
            return SourceCandidate(
                observation: observation,
                providerLifecycle: provider.lifecycle,
                providerHealth: provider.health,
                providerAvailability: provider.availability,
                freshness: observation.freshness(at: now, policy: policy.freshness),
                isAuthoritative: observation.source.providerID == authoritativeID,
                authorityReason: observation.source.providerID == authoritativeID ? decision.reason : nil
            )
        }
        return DataSourceMapEntry(observationID: id, candidates: sourceCandidates,
                                  authorityReason: decision.reason)
    }

    public func readCapability(for observationID: ObservationID, id capabilityID: CapabilityID,
                               policy: ReadAuthorityPolicy) async -> CapabilityState {
        let map = await sourceMapEntry(for: observationID, policy: policy)
        let declaredProviderIDs = providers.values
            .filter { $0.descriptor.observationIDs.contains(observationID) }
            .map { $0.descriptor.id }
        let providerIDs = Array(Set(map.candidates.map { $0.observation.source.providerID } + declaredProviderIDs)).sorted()
        if map.candidates.contains(where: \.isAuthoritative) {
            return CapabilityState(id: capabilityID, kind: .observation(observationID),
                                   availability: .available, providerIDs: providerIDs,
                                   reason: "A fresh, valid, healthy source is authoritative.")
        }
        if map.candidates.isEmpty && !declaredProviderIDs.isEmpty {
            return CapabilityState(id: capabilityID, kind: .observation(observationID),
                                   availability: .potential, providerIDs: providerIDs,
                                   reason: "A provider declares this observation, but no observation is available.")
        }
        return CapabilityState(id: capabilityID, kind: .observation(observationID),
                               availability: .unavailable, providerIDs: providerIDs,
                               reason: map.candidates.isEmpty
                                   ? "No source has supplied this observation."
                                   : "No observed source is currently eligible.")
    }
}
