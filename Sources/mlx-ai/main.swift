import Darwin
import Foundation
import MLXAIKit

@main
struct MLXAICLI {
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let json = arguments.contains("--json")
        arguments.removeAll { $0 == "--json" }
        let command = arguments.first ?? "start"
        let controller = ServiceController()

        do {
            switch command {
            case "start":
                let status = try await controller.start()
                emit(status, json: json, message: "MLX server is ready at \(status.endpoint)")
            case "stop":
                let status = try await controller.stop()
                emit(status, json: json, message: "MLX server stopped")
            case "restart":
                let status = try await controller.restart()
                emit(status, json: json, message: "MLX server restarted at \(status.endpoint)")
            case "status":
                let status = await controller.status()
                emit(status, json: json, message: "\(status.state.title.lowercased()) — \(status.detail)")
                if status.state != .running { exit(1) }
            case "logs":
                if json { throw MLXAIError.message("--json is not supported with logs") }
                let follow = arguments.contains("--follow")
                guard FileManager.default.fileExists(atPath: Paths.serverLog.path) else {
                    print("No server log exists yet at \(Paths.serverLog.path)")
                    return
                }
                let result = try SystemProcess.run("/usr/bin/tail", follow ? ["-n", "100", "-f", Paths.serverLog.path] : ["-n", "100", Paths.serverLog.path])
                print(result.output, terminator: result.output.hasSuffix("\n") ? "" : "\n")
                if result.status != 0 { exit(1) }
            case "doctor":
                let diagnostics = await controller.diagnostics()
                if json {
                    let data = try JSONSerialization.data(withJSONObject: ["diagnostics": diagnostics], options: [.prettyPrinted, .sortedKeys])
                    print(String(decoding: data, as: UTF8.self))
                } else { diagnostics.forEach { print($0) } }
            case "version", "--version", "-v":
                print("MLX AI 1.0.0")
            case "help", "--help", "-h":
                printHelp()
            default:
                fputs("mlx-ai: unknown command '\(command)'\n", stderr)
                printHelp()
                exit(2)
            }
        } catch {
            if json {
                let body = ["error": error.localizedDescription]
                if let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]) {
                    print(String(decoding: data, as: UTF8.self))
                }
            } else { fputs("mlx-ai: \(error.localizedDescription)\n", stderr) }
            exit(1)
        }
    }

    private static func emit(_ status: StatusSnapshot, json: Bool, message: String) {
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(status) { print(String(decoding: data, as: UTF8.self)) }
        } else {
            print(message)
            if status.state == .running {
                print("Model: \(status.model)")
                print("Memory: \(Formatting.bytes(status.rssBytes)) · Uptime: \(Formatting.duration(status.uptimeSeconds))")
            }
        }
    }

    private static func printHelp() {
        print("""
        MLX AI — control the local MLX server

        USAGE
          mlx-ai [start]          Start and wait for the API
          mlx-ai stop             Stop the managed server
          mlx-ai restart          Restart the managed server
          mlx-ai status [--json]  Show health and runtime details
          mlx-ai logs [--follow]  Read or follow the server log
          mlx-ai doctor [--json]  Validate the local environment
          mlx-ai version          Print the version
        """)
    }
}
