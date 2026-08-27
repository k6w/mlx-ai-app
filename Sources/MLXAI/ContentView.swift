import AppKit
import MLXAIKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if !model.runtimeChecked {
                VStack(spacing: 12) { BrandMark().frame(width: 52, height: 42); ProgressView(); Text("Preparing MLX AI…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, minHeight: 260)
            } else if !model.runtimeReady {
                SetupView(model: model)
            } else {
                mainContent
            }
        }
        .padding(16)
        .frame(width: 336)
        .sheet(isPresented: $model.showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $model.showDiagnostics) { DiagnosticsView(model: model) }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.vertical, 14)
            serverCard
            if let error = model.errorMessage { errorCard(error) }
            actions
            Divider().padding(.vertical, 12)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 11) {
            BrandMark().frame(width: 34, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("MLX AI").font(.system(size: 16, weight: .semibold))
                Text(model.status.state.title).font(.caption).foregroundStyle(stateColor)
            }
            Spacer()
            Circle().fill(stateColor).frame(width: 8, height: 8)
                .shadow(color: stateColor.opacity(0.35), radius: 3)
                .accessibilityLabel(model.status.state.title)
        }
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.status.model.components(separatedBy: "/").last ?? model.status.model)
                .font(.system(size: 13, weight: .medium)).lineLimit(1)
            Text(model.status.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                metric("MEMORY", Formatting.bytes(model.status.rssBytes))
                metric("UPTIME", Formatting.duration(model.status.uptimeSeconds))
                metric("PORT", String(model.configuration.port))
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private func metric(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 12, design: .rounded)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Button(action: model.primaryAction) {
                    HStack {
                        if model.isWorking { ProgressView().controlSize(.small) }
                        Image(systemName: primaryIcon)
                        Text(primaryTitle)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(model.isWorking || model.status.state == .external || model.status.state == .conflict)

                if model.status.state == .running {
                    Button(action: model.restart) { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.bordered).controlSize(.large).help("Restart server")
                        .disabled(model.isWorking)
                }
            }
            HStack(spacing: 6) {
                quickButton("Copy API", "doc.on.doc", model.copyEndpoint)
                quickButton("Check", "checkmark.circle", model.checkAPI)
                quickButton("Logs", "text.alignleft", model.openLog)
            }
        }.padding(.top, 12)
    }

    private func quickButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.caption).frame(maxWidth: .infinity) }
            .buttonStyle(.bordered)
    }

    private func errorCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10).background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 9)).padding(.top, 10)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { model.showSettings = true } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Settings")
            Button { model.loadDiagnostics() } label: { Image(systemName: "stethoscope") }.buttonStyle(.plain).help("Diagnostics")
            Button { model.revealLog() } label: { Image(systemName: "folder") }.buttonStyle(.plain).help("Reveal log")
            Spacer()
            Text("v1.0").font(.caption2).foregroundStyle(.tertiary)
            Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
        }.foregroundStyle(.secondary)
    }

    private var primaryTitle: String {
        switch model.status.state {
        case .running, .starting: "Stop Server"
        default: "Start Server"
        }
    }
    private var primaryIcon: String { model.status.state == .running || model.status.state == .starting ? "stop.fill" : "play.fill" }
    private var stateColor: Color {
        switch model.status.state {
        case .running: .green
        case .starting, .stopping: .orange
        case .external: .blue
        case .degraded, .conflict: .red
        case .stopped: .secondary
        }
    }
}

struct BrandMark: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 2, y: size.height - 3)); path.addLine(to: CGPoint(x: 2, y: 5))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height - 4)); path.addLine(to: CGPoint(x: size.width - 2, y: 5))
            path.addLine(to: CGPoint(x: size.width - 2, y: size.height - 3))
            context.stroke(path, with: .linearGradient(Gradient(colors: [.green, .cyan]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            var cross = Path(); cross.move(to: CGPoint(x: 5, y: 4)); cross.addLine(to: CGPoint(x: size.width - 5, y: size.height - 4))
            cross.move(to: CGPoint(x: size.width - 5, y: 4)); cross.addLine(to: CGPoint(x: 5, y: size.height - 4))
            context.stroke(cross, with: .color(.primary.opacity(0.78)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }
}

struct SetupView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(spacing: 14) {
            BrandMark().frame(width: 58, height: 46)
            Text("Set up MLX AI").font(.title2.bold())
            Text("MLX AI installs an isolated Python runtime in your user Library. It does not modify system Python or require administrator access.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 7) {
                Label("Apple Silicon required", systemImage: "cpu")
                Label("About 5 GB for the default model", systemImage: "internaldrive")
                Label("Downloaded only when first started", systemImage: "arrow.down.circle")
            }.font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Button(action: model.installRuntime) {
                HStack { if model.isInstallingRuntime { ProgressView().controlSize(.small) }; Text(model.isInstallingRuntime ? "Installing…" : "Install Runtime") }
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isInstallingRuntime)
            Text(model.setupDetail).font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
            HStack { Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain); Spacer(); Button("Check Again", action: model.checkRuntime).buttonStyle(.plain) }
                .font(.caption).foregroundStyle(.secondary)
        }.frame(minHeight: 330)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("MLX AI Settings").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            Toggle("Launch menu app at login", isOn: Binding(get: { model.configuration.launchAtLogin }, set: model.updateLaunchAtLogin))
            Toggle("Start server at login", isOn: Binding(get: { model.configuration.startServerAtLogin }, set: model.updateServerAtLogin))
            Text("Starting the server loads approximately 5 GB into memory.").font(.caption).foregroundStyle(.secondary)
            Toggle("Notify me about failures", isOn: Binding(get: { model.configuration.failureNotifications }, set: model.updateNotifications))
            Divider()
            LabeledContent("Model", value: model.configuration.model)
            LabeledContent("Endpoint", value: model.configuration.endpoint.absoluteString)
            LabeledContent("Python", value: model.configuration.pythonPath)
            Divider()
            HStack {
                VStack(alignment: .leading) { Text("Command-line tool"); if let message = model.cliInstallMessage { Text(message).font(.caption).foregroundStyle(.secondary) } }
                Spacer(); Button("Install CLI", action: model.installCLI)
            }
            HStack { Text("Updates"); Spacer(); Button("Check for Updates", action: model.checkForUpdates) }
        }.padding(22).frame(width: 480)
    }
}

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Diagnostics").font(.title2.bold()); Spacer(); Button("Done") { dismiss() } }
            ScrollView { Text(model.diagnostics.joined(separator: "\n")).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            HStack { Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(model.diagnostics.joined(separator: "\n"), forType: .string) }; Spacer(); Button("Open Log", action: model.openLog) }
        }.padding(22).frame(width: 600, height: 380)
    }
}
