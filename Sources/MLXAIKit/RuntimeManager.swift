import Foundation

public struct RuntimeManager: Sendable {
    public static let mlxLMVersion = "0.31.3"

    public init() {}

    public func isReady(pythonPath: String) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: pythonPath),
              let result = try? SystemProcess.run(pythonPath, ["-c", "import mlx_lm"])
        else { return false }
        return result.status == 0
    }

    public func install(using uvURL: URL) throws -> URL {
        guard FileManager.default.isExecutableFile(atPath: uvURL.path) else {
            throw MLXAIError.message("The runtime installer is missing. Reinstall MLX AI from an official release.")
        }
        try ConfigurationStore().ensureDirectories()
        let environment = ProcessInfo.processInfo.environment.merging([
            "UV_PYTHON_INSTALL_DIR": Paths.managedPythonDownloads.path,
            "UV_NO_PROGRESS": "1",
        ]) { _, new in new }

        try runUV(uvURL, ["python", "install", "3.11"], environment)
        try runUV(uvURL, ["venv", "--python", "3.11", "--python-preference", "only-managed", Paths.managedRuntime.path], environment)
        try runUV(uvURL, ["pip", "install", "--python", Paths.managedPython.path, "mlx-lm==\(Self.mlxLMVersion)"], environment)

        guard isReady(pythonPath: Paths.managedPython.path) else {
            throw MLXAIError.message("The MLX runtime installation finished but validation failed.")
        }
        return Paths.managedPython
    }

    public func bundledUV() -> URL? {
        if let bundled = Bundle.main.url(forResource: "uv", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        for path in ["/opt/homebrew/bin/uv", "/usr/local/bin/uv"] where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func runUV(_ executable: URL, _ arguments: [String], _ environment: [String: String]) throws {
        let result = try SystemProcess.run(executable.path, arguments, environment: environment)
        guard result.status == 0 else {
            let detail = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw MLXAIError.message(detail.isEmpty ? "Runtime installation failed." : detail)
        }
    }
}
