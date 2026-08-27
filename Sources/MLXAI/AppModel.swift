import AppKit
import Foundation
import MLXAIKit
import ServiceManagement
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var status: StatusSnapshot
    @Published var configuration: AppConfiguration
    @Published var isWorking = false
    @Published var errorMessage: String?
    @Published var showSettings = false
    @Published var showDiagnostics = false
    @Published var diagnostics: [String] = []
    @Published var runtimeChecked = false
    @Published var runtimeReady = false
    @Published var isInstallingRuntime = false
    @Published var setupDetail = "Checking the local MLX runtime…"
    @Published var cliInstallMessage: String?

    var onStatusChange: ((ServerState) -> Void)?
    private let controller = ServiceController()
    private var pollingTask: Task<Void, Never>?
    private var didApplyLoginPolicy = false

    init() {
        let config = (try? ConfigurationStore().load()) ?? AppConfiguration()
        configuration = config
        status = StatusSnapshot(state: .stopped, detail: "Checking local server…", endpoint: config.endpoint.absoluteString, model: config.model)
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard !Task.isCancelled else { return }
                let fast = self?.status.state == .starting || self?.status.state == .stopping
                try? await Task.sleep(for: fast ? .seconds(1) : .seconds(5))
            }
        }
        applyInitialLoginPolicy()
        checkRuntime()
    }

    func checkRuntime() {
        let pythonPath = configuration.pythonPath
        Task {
            let ready = await Task.detached { RuntimeManager().isReady(pythonPath: pythonPath) }.value
            runtimeReady = ready
            runtimeChecked = true
            setupDetail = ready ? "Runtime ready" : "Install the private MLX runtime to continue."
        }
    }

    func installRuntime() {
        guard !isInstallingRuntime else { return }
        guard let uv = RuntimeManager().bundledUV() else {
            errorMessage = "This development build does not include the runtime installer. Download an official release or install uv with Homebrew."
            return
        }
        isInstallingRuntime = true
        errorMessage = nil
        setupDetail = "Installing Python 3.11 and mlx-lm…"
        Task {
            do {
                let python = try await Task.detached { try RuntimeManager().install(using: uv) }.value
                configuration.pythonPath = python.path
                try await controller.save(configuration: configuration)
                runtimeReady = true
                setupDetail = "Runtime ready. The model downloads when you first start the server."
            } catch {
                errorMessage = error.localizedDescription
                setupDetail = "Runtime installation failed."
            }
            runtimeChecked = true
            isInstallingRuntime = false
        }
    }

    func refresh() async {
        let next = await controller.status()
        status = next
        onStatusChange?(next.state)
    }

    func primaryAction() {
        perform(status.state == .running || status.state == .starting ? .stop : .start)
    }

    func restart() { perform(.restart) }

    enum Action { case start, stop, restart }
    private func perform(_ action: Action) {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        if action == .start { status.state = .starting }
        if action == .stop { status.state = .stopping }
        onStatusChange?(status.state)
        Task {
            do {
                switch action {
                case .start: status = try await controller.start()
                case .stop: status = try await controller.stop()
                case .restart: status = try await controller.restart()
                }
            } catch {
                errorMessage = error.localizedDescription
                await notifyFailure(error.localizedDescription)
                await refresh()
            }
            isWorking = false
            onStatusChange?(status.state)
        }
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        configuration.launchAtLogin = enabled
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            try saveConfiguration()
        } catch { errorMessage = "Could not update the login item: \(error.localizedDescription)" }
    }

    func updateServerAtLogin(_ enabled: Bool) {
        configuration.startServerAtLogin = enabled
        do { try saveConfiguration() }
        catch { errorMessage = "Could not save settings: \(error.localizedDescription)" }
    }

    func updateNotifications(_ enabled: Bool) {
        configuration.failureNotifications = enabled
        do { try saveConfiguration() }
        catch { errorMessage = "Could not save settings: \(error.localizedDescription)" }
        if enabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    func loadDiagnostics() {
        Task {
            diagnostics = await controller.diagnostics()
            showDiagnostics = true
        }
    }

    func copyEndpoint() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(status.endpoint, forType: .string)
    }

    func checkAPI() {
        if let url = URL(string: status.endpoint + "/models") { NSWorkspace.shared.open(url) }
    }

    func openLog() { NSWorkspace.shared.open(Paths.serverLog) }
    func revealLog() { NSWorkspace.shared.activateFileViewerSelecting([Paths.serverLog]) }
    func checkForUpdates() { NSWorkspace.shared.open(URL(string: "https://github.com/k6w/mlx-ai-app/releases/latest")!) }

    func installCLI() {
        guard let source = Bundle.main.url(forResource: "mlx-ai", withExtension: nil) else {
            cliInstallMessage = "The companion CLI is missing from this build."
            return
        }
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin", isDirectory: true)
        let destination = directory.appendingPathComponent("mlx-ai")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                let backup = directory.appendingPathComponent("mlx-ai.backup-\(Int(Date().timeIntervalSince1970))")
                try FileManager.default.moveItem(at: destination, to: backup)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
            cliInstallMessage = "Installed at ~/.local/bin/mlx-ai"
        } catch { cliInstallMessage = "CLI installation failed: \(error.localizedDescription)" }
    }

    private func saveConfiguration() throws {
        try ConfigurationStore().save(configuration)
    }

    private func applyInitialLoginPolicy() {
        guard !didApplyLoginPolicy else { return }
        didApplyLoginPolicy = true
        if configuration.launchAtLogin { try? SMAppService.mainApp.register() }
        if configuration.failureNotifications {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        if configuration.startServerAtLogin {
            Task {
                await refresh()
                if status.state == .stopped { perform(.start) }
            }
        }
    }

    private func notifyFailure(_ text: String) async {
        guard configuration.failureNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "MLX AI needs attention"
        content.body = text
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

}
