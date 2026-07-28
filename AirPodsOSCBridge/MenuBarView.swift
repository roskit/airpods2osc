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
    }
}