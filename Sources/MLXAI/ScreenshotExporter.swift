import AppKit
import MLXAIKit
import SwiftUI

@MainActor
enum ScreenshotExporter {
    static func export(to directory: URL, model: AppModel) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try render(name: "mlx-ai-running-dark", state: .running, scheme: .dark, setup: false, to: directory, model: model)
        try render(name: "mlx-ai-stopped-light", state: .stopped, scheme: .light, setup: false, to: directory, model: model)
        try render(name: "mlx-ai-first-run", state: .stopped, scheme: .dark, setup: true, to: directory, model: model)
    }

    private static func render(
        name: String, state: ServerState, scheme: ColorScheme, setup: Bool,
        to directory: URL, model: AppModel
    ) throws {
        model.configureForScreenshot(state: state, setup: setup)
        let height: CGFloat = setup ? 420 : 430
        let content = ContentView(model: model)
            .frame(width: 336, height: setup ? 420 : 430)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .environment(\.colorScheme, scheme)
        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 336, height: height)
        let window = NSWindow(
            contentRect: hostingView.frame, styleMask: [.borderless],
            backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hostingView
        window.displayIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 672, pixelsHigh: Int(height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            throw MLXAIError.message("Could not allocate \(name).")
        }
        bitmap.size = hostingView.bounds.size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw MLXAIError.message("Could not render \(name).")
        }
        try png.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }
}
