import DTConfigCore
import DrawThingsClient

/// Server-backed ValueDomainProvider that checks file existence via DrawThingsService.
///
/// The current DrawThingsClient API only exposes `checkFilesExist` (verifying specific
/// filenames), not a model-listing endpoint. This provider therefore returns `nil`
/// (free-form) for all fields — it cannot enumerate available values. When a
/// model-browsing API becomes available in the client, this provider can be extended
/// to return actual domain values.
///
/// Degrades gracefully: when `service` is nil or the server is unreachable, behaves
/// identically to `StaticValueDomainProvider`.
public final class ServerValueDomainProvider: ValueDomainProvider, @unchecked Sendable {
    private let service: DrawThingsService?

    public init(service: DrawThingsService? = nil) {
        self.service = service
    }

    public func values(for field: FieldPath) async -> [DomainValue]? {
        // No listing API available — free-form for all fields
        nil
    }

    /// Check whether specific files exist on the connected Draw Things server.
    /// Returns nil if no service is configured or the call fails.
    public func checkFilesExist(_ files: [String]) async -> [String: Bool]? {
        guard let service else { return nil }
        do {
            let response = try await service.checkFilesExist(files: files)
            var result: [String: Bool] = [:]
            for (file, exists) in zip(response.files, response.existences) {
                result[file] = exists
            }
            return result
        } catch {
            return nil
        }
    }
}
