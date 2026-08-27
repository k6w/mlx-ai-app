import Foundation

public struct ConfigurationStore: Sendable {
    public init() {}

    public func load() throws -> AppConfiguration {
        try ensureDirectories()
        guard FileManager.default.fileExists(atPath: Paths.config.path) else {
            let initial = AppConfiguration()
            try save(initial)
            return initial
        }
        let data = try Data(contentsOf: Paths.config)
        return try JSONDecoder().decode(AppConfiguration.self, from: data)
    }

    public func save(_ configuration: AppConfiguration) throws {
        try ensureDirectories()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try data.write(to: Paths.config, options: .atomic)
    }

    public func ensureDirectories() throws {
        try FileManager.default.createDirectory(at: Paths.appSupport, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: Paths.logs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: Paths.launchAgent.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}
