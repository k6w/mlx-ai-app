import Foundation
import Testing
@testable import MLXAIKit

@Test func resolvesEveryRuntimeState() {
    #expect(StateResolver.resolve(healthy: true, managedPID: 12, listeningPID: 12, markerAge: 4, startupTimeout: 120) == .running)
    #expect(StateResolver.resolve(healthy: true, managedPID: nil, listeningPID: 99, markerAge: nil, startupTimeout: 120) == .external)
    #expect(StateResolver.resolve(healthy: false, managedPID: 12, listeningPID: 12, markerAge: 4, startupTimeout: 120) == .starting)
    #expect(StateResolver.resolve(healthy: false, managedPID: 12, listeningPID: 12, markerAge: 121, startupTimeout: 120) == .degraded)
    #expect(StateResolver.resolve(healthy: false, managedPID: nil, listeningPID: 99, markerAge: nil, startupTimeout: 120) == .conflict)
    #expect(StateResolver.resolve(healthy: false, managedPID: nil, listeningPID: nil, markerAge: nil, startupTimeout: 120) == .stopped)
}

@Test func configurationDefaultsAreSafeAndCompatible() {
    let configuration = AppConfiguration(pythonPath: "/tmp/python")
    #expect(configuration.host == "127.0.0.1")
    #expect(configuration.port == 8080)
    #expect(configuration.endpoint.absoluteString == "http://127.0.0.1:8080/v1")
    #expect(configuration.model == "LiquidAI/LFM2.5-8B-A1B-MLX-4bit")
    #expect(configuration.launchAtLogin)
    #expect(!configuration.startServerAtLogin)
}

@Test func configurationRoundTrips() throws {
    let original = AppConfiguration(pythonPath: "/example/python")
    let data = try JSONEncoder().encode(original)
    #expect(try JSONDecoder().decode(AppConfiguration.self, from: data) == original)
}

@Test func runtimeFormattingIsCompact() {
    #expect(Formatting.duration(59) == "59s")
    #expect(Formatting.duration(120) == "2m")
    #expect(Formatting.duration(3_661) == "1h 1m")
    #expect(Formatting.duration(nil) == "—")
}
