import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section("OSC Destination") {
                TextField("Host", text: $settings.destinationHost)
                TextField("Port", value: $settings.destinationPort, format: .number)
                    .onChange(of: settings.destinationPort) { _, port in
                        settings.destinationPort = min(max(port, 1), 65_535)
                    }
            }

            Section("Output") {
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
    }
}
