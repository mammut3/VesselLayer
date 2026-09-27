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

public enum AuthorityReason: Hashable, Codable, Sendable {
    case selectedOnlyEligibleCandidate
    case selectedByPolicyRank(rank: Int)
    case selectedByQuality
    case selectedByStableProviderID
    case noRegisteredCandidates
    case noEligibleCandidates
}

public struct AuthorityDecision: Hashable, Codable, Sendable {
    public var observation: AnyObservation?
    public var reason: AuthorityReason
    public var eligibleProviderIDs: [ProviderID]
    public init(observation: AnyObservation?, reason: AuthorityReason, eligibleProviderIDs: [ProviderID]) {
        self.observation = observation; self.reason = reason; self.eligibleProviderIDs = eligibleProviderIDs
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
}
