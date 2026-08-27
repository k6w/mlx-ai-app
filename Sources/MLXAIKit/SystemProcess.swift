import Foundation

public struct ProcessResult: Sendable {
    public let status: Int32
    public let output: String
}

public enum SystemProcess {
    @discardableResult
    public static func run(_ executable: String, _ arguments: [String], environment: [String: String]? = nil) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment { process.environment = environment }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ProcessResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }
}
