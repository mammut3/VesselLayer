public struct MonotonicInstant: Hashable, Codable, Sendable, Comparable {
    public var nanoseconds: UInt64
    public init(nanoseconds: UInt64) { self.nanoseconds = nanoseconds }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.nanoseconds < rhs.nanoseconds }
    public func advanced(by duration: Duration) -> Self {
        let parts = duration.components
        precondition(parts.seconds >= 0 && parts.attoseconds >= 0)
        let seconds = UInt64(parts.seconds)
        let nanos = UInt64(parts.attoseconds / 1_000_000_000)
        return Self(nanoseconds: nanoseconds &+ seconds &* 1_000_000_000 &+ nanos)
    }
}

public protocol VesselLayerClock: Sendable {
    func now() async -> MonotonicInstant
}

public struct FreshnessPolicy: Hashable, Codable, Sendable {
    public var freshForNanoseconds: UInt64
    public init(freshForNanoseconds: UInt64) { self.freshForNanoseconds = freshForNanoseconds }
    public init(freshFor duration: Duration) {
        let parts = duration.components
        precondition(parts.seconds >= 0 && parts.attoseconds >= 0)
        self.freshForNanoseconds = UInt64(parts.seconds) * 1_000_000_000 + UInt64(parts.attoseconds / 1_000_000_000)
    }
}

public enum FreshnessState: String, Codable, Sendable { case fresh, stale }
