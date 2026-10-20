import Foundation

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
    private var providerRegistrationIDs: [ProviderID: UUID] = [:]
    private var providerAvailabilityUpdates: [ProviderID: UUID] = [:]
    private var candidates: [ObservationID: [ProviderID: AnyObservation]] = [:]

    private struct Invalidation {
        var source: ObservationSource
        var receivedAt: MonotonicInstant
        var matchingAttributes: [String: String]
        func matches(_ source: ObservationSource) -> Bool {
            matchingAttributes.allSatisfy { source.attributes[$0.key] == $0.value }
        }
    }
    private var invalidations: [ObservationID: [ProviderID: Invalidation]] = [:]

    public init(clock: any VesselLayerClock) { self.clock = clock }

    @discardableResult public func register(_ descriptor: ProviderDescriptor) async -> ProviderState {
        let now = await clock.now()
        if let existing = providers[descriptor.id] { return existing }
        let state = ProviderState(descriptor: descriptor, updatedAt: now)
        providers[descriptor.id] = state
        providerRegistrationIDs[descriptor.id] = UUID()
        return state
    }

    public func updateProvider(_ id: ProviderID, lifecycle: ProviderLifecycle, health: ProviderHealth) async {
        // Clock reads can suspend. Inspect terminal lifecycle only after that hop,
        // with no suspension between the final check and mutation.
        let update = UUID()
        providerAvailabilityUpdates[id] = update
        let now = await clock.now()
        guard providerAvailabilityUpdates[id] == update,
              var state = providers[id], state.lifecycle != .withdrawn else { return }
        state.lifecycle = lifecycle; state.health = health; state.updatedAt = now; providers[id] = state
    }

    public func withdrawProvider(_ id: ProviderID) async {
        let now = await clock.now()
        guard var state = providers[id] else { return }
        state.lifecycle = .withdrawn; state.updatedAt = now; providers[id] = state
    }

    /// Permanently removes a provider and all of its latest observation candidates.
    /// Use withdrawal when historical/current-state inspection is still useful; use
    /// removal for session-scoped identities that are no longer meaningful.
    public func removeProvider(_ id: ProviderID) {
        providers.removeValue(forKey: id)
        providerRegistrationIDs.removeValue(forKey: id)
        providerAvailabilityUpdates.removeValue(forKey: id)
        for observationID in Array(invalidations.keys) {
            invalidations[observationID]?.removeValue(forKey: id)
            if invalidations[observationID]?.isEmpty == true { invalidations.removeValue(forKey: observationID) }
        }
        for observationID in Array(candidates.keys) {
            candidates[observationID]?.removeValue(forKey: id)
            if candidates[observationID]?.isEmpty == true {
                candidates.removeValue(forKey: observationID)
            }
        }
    }

    /// Atomically replaces a provisional provider identity with a stronger generic
    /// provider descriptor. Latest observations follow the durable provider without
    /// leaving the provisional source eligible as a duplicate candidate.
    public func reconcileProvider(from provisionalID: ProviderID,
                                  to durableDescriptor: ProviderDescriptor) async {
        let now = await clock.now()
        guard provisionalID != durableDescriptor.id,
              let provisional = providers[provisionalID]
        else {
            if provisionalID == durableDescriptor.id, var current = providers[provisionalID] {
                current.descriptor = durableDescriptor
                current.updatedAt = now
                providers[provisionalID] = current
            }
            return
        }

        if var durable = providers[durableDescriptor.id] {
            durable.descriptor = durableDescriptor
            providers[durableDescriptor.id] = durable
        } else {
            providers[durableDescriptor.id] = ProviderState(
                descriptor: durableDescriptor,
                lifecycle: provisional.lifecycle,
                health: provisional.health,
                updatedAt: provisional.updatedAt)
            providerRegistrationIDs[durableDescriptor.id] = UUID()
        }

        // Migrate validity evidence even when no numeric observation preceded it.
        for observationID in Set(candidates.keys).union(invalidations.keys) {
            if var event = invalidations[observationID]?.removeValue(forKey: provisionalID) {
                event.source.providerID = durableDescriptor.id
                event.source.assetID = durableDescriptor.assetID
                if event.receivedAt.nanoseconds > (invalidations[observationID]?[durableDescriptor.id]?.receivedAt.nanoseconds ?? 0) || invalidations[observationID]?[durableDescriptor.id] == nil {
                    invalidations[observationID, default: [:]][durableDescriptor.id] = event
                }
            }
            guard var byProvider = candidates[observationID],
                  var provisionalObservation = byProvider.removeValue(forKey: provisionalID)
            else { continue }
            provisionalObservation.source.providerID = durableDescriptor.id
            if let assetID = durableDescriptor.assetID {
                provisionalObservation.source.assetID = assetID
            }
            if let existing = byProvider[durableDescriptor.id] {
                if provisionalObservation.receivedAt.nanoseconds > existing.receivedAt.nanoseconds {
                    byProvider[durableDescriptor.id] = provisionalObservation
                }
            } else {
                byProvider[durableDescriptor.id] = provisionalObservation
            }
            candidates[observationID] = byProvider
        }
        for observationID in Array(invalidations.keys) {
            if let event = invalidations[observationID]?[durableDescriptor.id],
               var observation = candidates[observationID]?[durableDescriptor.id] {
                if !event.matches(observation.source) {
                    invalidations[observationID]?.removeValue(forKey: durableDescriptor.id)
                } else if event.receivedAt.nanoseconds >= observation.receivedAt.nanoseconds {
                    observation.validity = .unavailable
                    candidates[observationID]?[durableDescriptor.id] = observation
                } else { invalidations[observationID]?.removeValue(forKey: durableDescriptor.id) }
            }
        }
        providers.removeValue(forKey: provisionalID)
        providerRegistrationIDs.removeValue(forKey: provisionalID)
        providerAvailabilityUpdates.removeValue(forKey: provisionalID)
    }

    /// Opaque process-local registration identity for dependent projection caches.
    /// Health/presence updates preserve identity; removal and new registration do not.
    public func providerRegistrations(requiringAvailability: Bool = false) -> [ProviderID: UUID] {
        providerRegistrationIDs.filter { id, _ in
            !requiringAvailability || providers[id]?.availability == .available
        }
    }

    public func providerState(_ id: ProviderID) -> ProviderState? { providers[id] }

    public func allProviderStates() -> [ProviderState] {
        providers.values.sorted { $0.descriptor.id < $1.descriptor.id }
    }

    @discardableResult public func ingest(_ observation: AnyObservation) -> Bool {
        let providerID = observation.source.providerID
        guard providers[providerID] != nil else { return false }
        if let event = invalidations[observation.id]?[providerID], event.matches(observation.source),
           observation.receivedAt.nanoseconds <= event.receivedAt.nanoseconds { return false }
        // A completed multi-part observation retains its original receipt time.
        // Equal timestamps retain arrival-order replacement, including invalidation.
        if let current = candidates[observation.id]?[observation.source.providerID],
           current.receivedAt.nanoseconds > observation.receivedAt.nanoseconds { return false }
        invalidations[observation.id]?.removeValue(forKey: providerID)
        candidates[observation.id, default: [:]][providerID] = observation
        return true
    }

    /// Ordered field-validity evidence without a fabricated measurement. The
    /// adapter supplies the source/session attributes that must match. A negative
    /// must be strictly newer; nil time retires the current matching reading at
    /// its existing evidence boundary (for source/session disappearance).
    /// Last measured value, provenance and receipt time remain diagnostic only.
    @discardableResult public func invalidate(_ id: ObservationID, from source: ObservationSource,
                                              at receivedAt: MonotonicInstant?,
                                              matchingAttributes: [String: String]) -> Bool {
        let providerID = source.providerID
        guard providers[providerID] != nil else { return false }
        let current = candidates[id]?[providerID]
        let previous = invalidations[id]?[providerID]
        func matches(_ candidate: ObservationSource) -> Bool {
            matchingAttributes.allSatisfy { candidate.attributes[$0.key] == $0.value }
        }
        // An already retired diagnostic from another stream must not prevent a
        // replacement stream from establishing its own negative-only boundary.
        if let current, current.validity == .valid, !matches(current.source) { return false }
        let latest = max(current?.receivedAt.nanoseconds ?? 0, previous?.receivedAt.nanoseconds ?? 0)
        let stamp: MonotonicInstant
        if let receivedAt {
            guard (current == nil && previous == nil) || receivedAt.nanoseconds > latest else { return false }
            stamp = receivedAt
        } else {
            // Lifecycle retirement is a compare-and-set of the captured reading.
            guard let current, current.validity == .valid, current.source == source else { return false }
            stamp = .init(nanoseconds: latest)
        }
        invalidations[id, default: [:]][providerID] = .init(source: source, receivedAt: stamp, matchingAttributes: matchingAttributes)
        if var current {
            current.validity = .unavailable
            candidates[id]?[providerID] = current
        }
        return true
    }

    public func allCandidates(for id: ObservationID) -> [AnyObservation] {
        Array(candidates[id, default: [:]].values).sorted { $0.source.providerID < $1.source.providerID }
    }

    public func authority(for id: ObservationID, policy: ReadAuthorityPolicy) async -> AuthorityDecision {
        let now = await clock.now()
        return authoritySnapshot(for: id, policy: policy, at: now)
    }

    /// Selection and row construction run without actor suspension after the clock.
    private func authoritySnapshot(for id: ObservationID, policy: ReadAuthorityPolicy,
                                   at now: MonotonicInstant) -> AuthorityDecision {
        guard let registered = candidates[id], !registered.isEmpty else {
            return AuthorityDecision(observation: nil, reason: .noRegisteredCandidates, eligibleProviderIDs: [])
        }
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
        let now = await clock.now()
        return sourceMapSnapshot(for: id, policy: policy, at: now)
    }

    private func sourceMapSnapshot(for id: ObservationID, policy: ReadAuthorityPolicy,
                                   at now: MonotonicInstant) -> DataSourceMapEntry {
        let decision = authoritySnapshot(for: id, policy: policy, at: now)
        let authoritativeID = decision.observation?.source.providerID
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
        let now = await clock.now()
        let map = sourceMapSnapshot(for: observationID, policy: policy, at: now)
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
