import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
                Text(appState.status.rawValue)
                    .font(.headline)
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
                GridRow { Text("Destination"); Text("\(appState.settings.destinationHost):\(appState.settings.destinationPort)") }
                GridRow { Text("Send rate"); Text("\(appState.measuredSendRate, format: .number.precision(.fractionLength(1))) packets/s") }
                GridRow { Text("Packets"); Text("\(appState.packetCount)") }
                GridRow { Text("Yaw"); Text(angle(appState.yaw)) }
                GridRow { Text("Pitch"); Text(angle(appState.pitch)) }
                GridRow { Text("Roll"); Text(angle(appState.roll)) }
            }
            .font(.system(.caption, design: .monospaced))

            if let error = appState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Start", action: appState.start)
                    .disabled(appState.isStreaming || !appState.motionAvailable)
                Button("Stop", action: appState.stop)
                    .disabled(!appState.isStreaming)
                Button("Recenter", action: appState.recenter)
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(!appState.isStreaming)
            }

            HStack {
                Button("Settings", action: openSettingsWindow)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var statusColor: Color {
        switch appState.status {
        case .streaming: .green
        case .ready: .yellow
        case .error, .unavailable, .headphonesDisconnected, .permissionNeeded: .red
        }
    }

    private func angle(_ value: Double) -> String {
        String(format: "%.4f rad", value)
    }

    private func openSettingsWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openSettings()
        DispatchQueue.main.async {
            let settingsWindow = NSApplication.shared.windows.first { window in
                window.title == "Settings"
            }
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }
}

struct MenuBarWindowConfigurator: NSViewRepresentable {
    let visibilityDidChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = MenuBarWindowObserver()
        view.visibilityDidChange = visibilityDidChange
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? MenuBarWindowObserver else { return }
        view.visibilityDidChange = visibilityDidChange
    }
}

private final class MenuBarWindowObserver: NSView {
    var visibilityDidChange: ((Bool) -> Void)?
    private var visibilityObservation: NSKeyValueObservation?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        wantsLayer = true
        layer?.isOpaque = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        visibilityObservation = window.observe(\.isVisible, options: [.initial, .new]) { [weak self] window, _ in
            DispatchQueue.main.async {
                self?.visibilityDidChange?(window.isVisible)
            }
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            visibilityObservation = nil
            visibilityDidChange?(false)
        }
        super.viewWillMove(toWindow: newWindow)
    }
}