import VesselLayer

public actor ManualClock: VesselLayerClock {
    private var instant: MonotonicInstant
    public init(initial: MonotonicInstant = .init(nanoseconds: 0)) { instant = initial }
    public func now() -> MonotonicInstant { instant }
    public func advance(by duration: Duration) { instant = instant.advanced(by: duration) }
    public func set(_ value: MonotonicInstant) { precondition(value >= instant); instant = value }
}

public enum TestProviders {
    public static func descriptor(_ id: String, vessel: String = "test-vessel") -> ProviderDescriptor {
        ProviderDescriptor(id: ProviderID(rawValue: id), vesselID: VesselID(rawValue: vessel), label: id)
    }
}
