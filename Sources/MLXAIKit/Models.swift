import Foundation

public enum ServerState: String, Codable, Sendable {
    case stopped, starting, stopping, running, external, degraded, conflict

    public var title: String {
        switch self {
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .stopping: "Stopping"
        case .running: "Running"
        case .external: "External server"
        case .degraded: "Needs attention"
        case .conflict: "Port conflict"
        }
    }
}

public struct StatusSnapshot: Codable, Equatable, Sendable {
    public var state: ServerState
    public var detail: String
    public var pid: Int32?
    public var endpoint: String
    public var model: String
    public var rssBytes: UInt64?
    public var uptimeSeconds: TimeInterval?

    public init(
        state: ServerState, detail: String, pid: Int32? = nil,
        endpoint: String, model: String, rssBytes: UInt64? = nil,
        uptimeSeconds: TimeInterval? = nil
    ) {
        self.state = state
        self.detail = detail
        self.pid = pid
        self.endpoint = endpoint
        self.model = model
        self.rssBytes = rssBytes
        self.uptimeSeconds = uptimeSeconds
    }
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var model = "LiquidAI/LFM2.5-8B-A1B-MLX-4bit"
    public var host = "127.0.0.1"
    public var port = 8080
    public var pythonPath: String
    public var launchAtLogin = true
    public var startServerAtLogin = false
    public var failureNotifications = true
    public var startupTimeoutSeconds: TimeInterval = 120

    public init(pythonPath: String = Paths.preferredPython.path) {
        self.pythonPath = pythonPath
    }

    public var endpoint: URL {
        URL(string: "http://\(host):\(port)/v1")!
    }

    public var modelsEndpoint: URL {
        endpoint.appendingPathComponent("models")
    }
}

public enum Paths {
    public static let home = FileManager.default.homeDirectoryForCurrentUser
    public static let appSupport = home.appendingPathComponent("Library/Application Support/MLX AI", isDirectory: true)
    public static let logs = home.appendingPathComponent("Library/Logs/MLX AI", isDirectory: true)
    public static let config = appSupport.appendingPathComponent("config.json")
    public static let marker = appSupport.appendingPathComponent("runtime.json")
    public static let lock = appSupport.appendingPathComponent("control.lock")
    public static let launchAgent = home.appendingPathComponent("Library/LaunchAgents/com.drwn.mlxai.server.plist")
    public static let serverLog = logs.appendingPathComponent("server.log")
    public static let legacyPython = home.appendingPathComponent(".mlx-venv/bin/python")
    public static let managedRuntime = appSupport.appendingPathComponent("runtime", isDirectory: true)
    public static let managedPython = managedRuntime.appendingPathComponent("bin/python")
    public static let managedPythonDownloads = appSupport.appendingPathComponent("python", isDirectory: true)
    public static var preferredPython: URL {
        FileManager.default.isExecutableFile(atPath: legacyPython.path) ? legacyPython : managedPython
    }
}

public enum MLXAIError: LocalizedError, Sendable {
    case message(String)

    public var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

public enum Formatting {
    public static func bytes(_ value: UInt64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    public static func duration(_ interval: TimeInterval?) -> String {
        guard let interval else { return "—" }
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        return "\(seconds / 3_600)h \((seconds % 3_600) / 60)m"
    }
}

public enum StateResolver {
    public static func resolve(
        healthy: Bool, managedPID: Int32?, listeningPID: Int32?,
        markerAge: TimeInterval?, startupTimeout: TimeInterval
    ) -> ServerState {
        if healthy { return managedPID == nil ? .external : .running }
        if managedPID != nil {
            return (markerAge ?? startupTimeout + 1) <= startupTimeout ? .starting : .degraded
        }
        if listeningPID != nil { return .conflict }
        if markerAge != nil { return .degraded }
        return .stopped
    }
}
