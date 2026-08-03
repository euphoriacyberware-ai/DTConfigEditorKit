public protocol ValueDomainProvider: Sendable {
    func values(for field: FieldPath) async -> [DomainValue]?
}

public struct StaticValueDomainProvider: ValueDomainProvider, Sendable {
    public init() {}

    public func values(for field: FieldPath) async -> [DomainValue]? {
        nil
    }
}
