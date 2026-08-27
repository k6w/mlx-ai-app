import AppKit
import MLXAIKit
import SwiftUI

@main
struct MLXAIApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let flag = CommandLine.arguments.firstIndex(of: "--export-screenshots"),
           CommandLine.arguments.indices.contains(flag + 1) {
            do {
                try ScreenshotExporter.export(to: URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true), model: model)
                NSApp.terminate(nil)
            } catch {
                fputs("MLX AI screenshot export failed: \(error.localizedDescription)\n", stderr)
                NSApp.terminate(nil)
            }
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: 28)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "MLX AI — checking server"
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 336, height: 430)
        popover.contentViewController = NSHostingController(rootView: ContentView(model: model))
        model.onStatusChange = { [weak self] state in self?.updateStatusItem(state) }
        updateStatusItem(.stopped)
        model.startPolling()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            Task { await model.refresh() }
        }
    }

    private func updateStatusItem(_ state: ServerState) {
        statusItem.button?.image = StatusIcon.image(state: state)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "MLX AI — \(state.title)"
        statusItem.button?.setAccessibilityLabel("MLX AI, \(state.title.lowercased())")
    }
}

enum StatusIcon {
    static func image(state: ServerState) -> NSImage {
        let image = NSImage(size: NSSize(width: 26, height: 18))
        image.lockFocus()
        NSColor.labelColor.setStroke()
        let mark = NSBezierPath()
        mark.lineWidth = 1.8; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
        mark.move(to: NSPoint(x: 2, y: 4)); mark.line(to: NSPoint(x: 2, y: 14)); mark.line(to: NSPoint(x: 8.5, y: 5)); mark.line(to: NSPoint(x: 15, y: 14)); mark.line(to: NSPoint(x: 15, y: 4)); mark.stroke()
        let cross = NSBezierPath(); cross.lineWidth = 1.25; cross.lineCapStyle = .round
        cross.move(to: NSPoint(x: 4, y: 4)); cross.line(to: NSPoint(x: 13, y: 14)); cross.move(to: NSPoint(x: 13, y: 4)); cross.line(to: NSPoint(x: 4, y: 14)); cross.stroke()
        badgeColor(state).setFill()
        NSBezierPath(ovalIn: NSRect(x: 19, y: 6, width: 7, height: 7)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func badgeColor(_ state: ServerState) -> NSColor {
        switch state {
        case .running: .systemGreen
        case .starting, .stopping: .systemOrange
        case .external: .systemBlue
        case .degraded, .conflict: .systemRed
        case .stopped: .tertiaryLabelColor
        }
    }
}
