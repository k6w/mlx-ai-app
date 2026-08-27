import Darwin
import Foundation

private struct RuntimeMarker: Codable {
    var requestedAt: Date
}

public actor ServiceController {
    public static let label = "com.drwn.mlxai.server"
    private let store: ConfigurationStore
    private let session: URLSession

    public init(store: ConfigurationStore = .init()) {
        self.store = store
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        self.session = URLSession(configuration: configuration)
    }

    public func configuration() throws -> AppConfiguration { try store.load() }

    public func save(configuration: AppConfiguration) throws {
        guard configuration.host == "127.0.0.1" else {
            throw MLXAIError.message("MLX AI v1 only permits the local host 127.0.0.1.")
        }
        guard (1...65_535).contains(configuration.port) else {
            throw MLXAIError.message("Port must be between 1 and 65535.")
        }
        try store.save(configuration)
    }

    public func status() async -> StatusSnapshot {
        let config = (try? store.load()) ?? AppConfiguration()
        let managedPID = launchdPID()
        let healthy = await healthCheck(config)
        let portPID = listeningPID(port: config.port)
        let marker = runtimeMarker()
        let markerAge = marker.map { Date().timeIntervalSince($0.requestedAt) }
        let resolved = StateResolver.resolve(
            healthy: healthy, managedPID: managedPID, listeningPID: portPID,
            markerAge: markerAge, startupTimeout: config.startupTimeoutSeconds
        )

        if resolved == .running, let pid = managedPID {
            return snapshot(.running, "OpenAI-compatible API is ready", config, pid, marker)
        }
        if resolved == .external {
            return snapshot(.external, "A compatible server is running outside MLX AI", config, portPID, marker)
        }
        if let pid = managedPID {
            if resolved == .starting {
                return snapshot(.starting, "Loading \(config.model.components(separatedBy: "/").last ?? config.model)…", config, pid, marker)
            }
            return snapshot(.degraded, "The server process is running but its API is not healthy", config, pid, marker)
        }
        if resolved == .conflict, let portPID {
            return snapshot(.conflict, "Port \(config.port) is occupied by process \(portPID)", config, portPID, nil)
        }
        if resolved == .degraded {
            return snapshot(.degraded, "The server exited before becoming healthy. Open the log for details.", config, nil, marker)
        }
        return snapshot(.stopped, "Start the local model when you need it", config, nil, nil)
    }

    public func start(waitUntilHealthy: Bool = true) async throws -> StatusSnapshot {
        let config = try store.load()
        try validate(config)
        let before = await status()
        if before.state == .running { return before }
        if before.state == .external || before.state == .conflict {
            throw MLXAIError.message(before.detail)
        }

        try withControlLock {
            try rotateLogs()
            try writeLaunchAgent(config)
            try writeMarker()
            let domain = "gui/\(getuid())"
            let bootstrap = try SystemProcess.run("/bin/launchctl", ["bootstrap", domain, Paths.launchAgent.path])
            if bootstrap.status != 0 && !bootstrap.output.localizedCaseInsensitiveContains("already") && !bootstrap.output.contains("37") {
                throw MLXAIError.message("Could not load the server service: \(bootstrap.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            let kickstart = try SystemProcess.run("/bin/launchctl", ["kickstart", "-k", "\(domain)/\(Self.label)"])
            guard kickstart.status == 0 else {
                throw MLXAIError.message("Could not start the server: \(kickstart.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        guard waitUntilHealthy else { return await status() }
        let deadline = Date().addingTimeInterval(config.startupTimeoutSeconds)
        while Date() < deadline {
            try await Task.sleep(for: .seconds(1))
            let current = await status()
            if current.state == .running { return current }
            if current.state == .degraded || current.state == .conflict { throw MLXAIError.message(current.detail) }
        }
        throw MLXAIError.message("Startup timed out after \(Int(config.startupTimeoutSeconds)) seconds. Check \(Paths.serverLog.path).")
    }

    public func stop() async throws -> StatusSnapshot {
        let current = await status()
        guard current.state != .stopped else { return current }
        guard current.state != .external && current.state != .conflict else {
            throw MLXAIError.message("Refusing to stop a process MLX AI does not manage.")
        }

        let pid = current.pid
        try withControlLock {
            let service = "gui/\(getuid())/\(Self.label)"
            let result = try SystemProcess.run("/bin/launchctl", ["bootout", service])
            if result.status != 0 && !result.output.localizedCaseInsensitiveContains("no such process") {
                throw MLXAIError.message("Could not stop the server: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        if let pid {
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline, Darwin.kill(pid, 0) == 0 {
                try await Task.sleep(for: .milliseconds(250))
            }
            if Darwin.kill(pid, 0) == 0 { Darwin.kill(pid, SIGKILL) }
        }
        try? FileManager.default.removeItem(at: Paths.marker)
        return await status()
    }

    public func restart() async throws -> StatusSnapshot {
        _ = try await stop()
        return try await start()
    }

    public func diagnostics() async -> [String] {
        let config = (try? store.load()) ?? AppConfiguration()
        var rows = [
            "macOS architecture: \(machineArchitecture())",
            "Python: \(config.pythonPath)",
            "Model: \(config.model)",
            "Endpoint: \(config.endpoint.absoluteString)",
            "Configuration: \(Paths.config.path)",
            "Log: \(Paths.serverLog.path)",
        ]
        rows.append(FileManager.default.isExecutableFile(atPath: config.pythonPath) ? "Python executable: OK" : "Python executable: MISSING — install it from the MLX AI setup screen")
        if FileManager.default.isExecutableFile(atPath: config.pythonPath),
           let result = try? SystemProcess.run(config.pythonPath, ["-c", "import mlx_lm; print('OK')"]) {
            rows.append("mlx_lm import: \(result.status == 0 ? "OK" : "FAILED")")
        }
        let current = await status()
        rows.append("State: \(current.state.rawValue) — \(current.detail)")
        return rows
    }

    private func validate(_ config: AppConfiguration) throws {
        guard machineArchitecture() == "arm64" else { throw MLXAIError.message("MLX AI requires an Apple Silicon Mac.") }
        guard config.host == "127.0.0.1" else { throw MLXAIError.message("The server must remain bound to 127.0.0.1.") }
        guard FileManager.default.isExecutableFile(atPath: config.pythonPath) else {
            throw MLXAIError.message("Python was not found at \(config.pythonPath).")
        }
        let result = try SystemProcess.run(config.pythonPath, ["-c", "import mlx_lm"])
        guard result.status == 0 else { throw MLXAIError.message("mlx_lm is not installed in \(config.pythonPath).") }
    }

    private func healthCheck(_ config: AppConfiguration) async -> Bool {
        do {
            let (data, response) = try await session.data(from: config.modelsEndpoint)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["data"] is [Any] else { return false }
            return true
        } catch { return false }
    }

    private func launchdPID() -> Int32? {
        let result = try? SystemProcess.run("/bin/launchctl", ["print", "gui/\(getuid())/\(Self.label)"])
        guard result?.status == 0, let output = result?.output else { return nil }
        let regex = try? NSRegularExpression(pattern: #"\bpid\s*=\s*(\d+)"#)
        guard let match = regex?.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
              let range = Range(match.range(at: 1), in: output) else { return nil }
        return Int32(output[range])
    }

    private func listeningPID(port: Int) -> Int32? {
        guard let result = try? SystemProcess.run("/usr/sbin/lsof", ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN", "-t"]),
              result.status == 0 else { return nil }
        return result.output.split(whereSeparator: \.isNewline).first.flatMap { Int32($0) }
    }

    private func residentBytes(pid: Int32?) -> UInt64? {
        guard let pid, let result = try? SystemProcess.run("/bin/ps", ["-o", "rss=", "-p", "\(pid)"]), result.status == 0,
              let kib = UInt64(result.output.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return kib * 1_024
    }

    private func snapshot(_ state: ServerState, _ detail: String, _ config: AppConfiguration, _ pid: Int32?, _ marker: RuntimeMarker?) -> StatusSnapshot {
        StatusSnapshot(
            state: state, detail: detail, pid: pid,
            endpoint: config.endpoint.absoluteString, model: config.model,
            rssBytes: residentBytes(pid: pid),
            uptimeSeconds: marker.map { Date().timeIntervalSince($0.requestedAt) }
        )
    }

    private func writeLaunchAgent(_ config: AppConfiguration) throws {
        try store.ensureDirectories()
        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [config.pythonPath, "-m", "mlx_lm", "server", "--model", config.model, "--port", "\(config.port)", "--host", config.host],
            "WorkingDirectory": Paths.home.path,
            "StandardOutPath": Paths.serverLog.path,
            "StandardErrorPath": Paths.serverLog.path,
            "RunAtLoad": false,
            "KeepAlive": false,
            "ProcessType": "Interactive",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: Paths.launchAgent, options: .atomic)
    }

    private func writeMarker() throws {
        let data = try JSONEncoder().encode(RuntimeMarker(requestedAt: Date()))
        try data.write(to: Paths.marker, options: .atomic)
    }

    private func runtimeMarker() -> RuntimeMarker? {
        guard let data = try? Data(contentsOf: Paths.marker) else { return nil }
        return try? JSONDecoder().decode(RuntimeMarker.self, from: data)
    }

    private func rotateLogs() throws {
        try store.ensureDirectories()
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: Paths.serverLog.path),
              let size = attributes[.size] as? UInt64, size > 10 * 1_024 * 1_024 else { return }
        let fm = FileManager.default
        for index in stride(from: 3, through: 1, by: -1) {
            let source = Paths.logs.appendingPathComponent("server.log.\(index)")
            let destination = Paths.logs.appendingPathComponent("server.log.\(index + 1)")
            if index == 3 { try? fm.removeItem(at: source) }
            else if fm.fileExists(atPath: source.path) { try? fm.moveItem(at: source, to: destination) }
        }
        try? fm.moveItem(at: Paths.serverLog, to: Paths.logs.appendingPathComponent("server.log.1"))
    }

    private func withControlLock<T>(_ work: () throws -> T) throws -> T {
        try store.ensureDirectories()
        let descriptor = Darwin.open(Paths.lock.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw MLXAIError.message("Could not open the lifecycle lock.") }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw MLXAIError.message("Could not acquire the lifecycle lock.") }
        defer { flock(descriptor, LOCK_UN) }
        return try work()
    }
}

private func machineArchitecture() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafePointer(to: &info.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
}
