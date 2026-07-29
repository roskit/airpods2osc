import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var settings: SettingsStore

    init(appState: AppState) {
        self.appState = appState
        _settings = ObservedObject(wrappedValue: appState.settings)
    }

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
                        
            
            HStack {
                Button("Start", action: appState.start)
                    .disabled(appState.isStreaming || !appState.motionAvailable)
                Button("Stop", action: appState.stop)
                    .disabled(!appState.isStreaming)
                Button("Recenter", action: appState.recenter)
                    .keyboardShortcut("k", modifiers: .command)
                    .disabled(!appState.isStreaming)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5) {
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

            settingsView
                .frame(maxHeight: .infinity)
                .background(.white)

            Divider()

            HStack {
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 400, height: 640)
    }

    private var statusColor: Color {
        switch appState.status {
        case .streaming: .green
        case .ready: .yellow
        case .error, .unavailable, .headphonesDisconnected, .permissionNeeded: .red
        }
    }

    private func angle(_ value: Double) -> String {
        String(format: "%.2f rad", value)
    }

    private var settingsView: some View {
        Form {
            Section("Config") {
                Picker("Preset", selection: Binding(
                    get: { settings.selectedPresetID },
                    set: settings.selectPreset
                )) {
                    Text("Custom").tag("custom")
                    ForEach(settings.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                Picker("Maximum send rate", selection: $settings.maximumSendRate) {
                    Text("20 Hz").tag(20)
                    Text("50 Hz").tag(50)
                    Text("100 Hz").tag(100)
                    Text("120 Hz").tag(120)
                    Text("Unlimited").tag(0)
                }

            }

            Section("OSC Destination") {
                TextField("Host", text: $settings.destinationHost)
                TextField("Port", value: $settings.destinationPort, format: .number)
                    .onChange(of: settings.destinationPort) { _, port in
                        settings.destinationPort = min(max(port, 1), 65_535)
                    }
            }

            Section("Advanced") {
                Toggle("Send quaternion", isOn: $settings.sendQuaternion)
                Picker("Quaternion forward axis", selection: $settings.quaternionForwardAxis) {
                    ForEach(QuaternionForwardAxis.allCases, id: \.self) { axis in
                        Text(axis.displayName).tag(axis)
                    }
                }
                .disabled(!settings.sendQuaternion)
                TextField("Quaternion address", text: $settings.quaternionAddress)
                    .disabled(!settings.sendQuaternion)
                Toggle("Send Euler angles (radians)", isOn: $settings.sendEuler)
                TextField("Euler address", text: $settings.eulerAddress)
                    .disabled(!settings.sendEuler)
                Toggle("Send gyroscope", isOn: $settings.sendGyroscope)
                TextField("Gyroscope address", text: $settings.gyroscopeAddress)
                    .disabled(!settings.sendGyroscope)
                Toggle("Send acceleration", isOn: $settings.sendAcceleration)
                TextField("Acceleration address", text: $settings.accelerationAddress)
                    .disabled(!settings.sendAcceleration)
                HStack {
                    Spacer()
                    Button("Reset OSC addresses", action: settings.resetOSCAddresses)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.all, 0)
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
