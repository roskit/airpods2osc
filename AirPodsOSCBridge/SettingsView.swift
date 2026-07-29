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
                Picker("Maximum send rate", selection: $settings.maximumSendRate) {
                    Text("30 Hz").tag(30)
                    Text("60 Hz").tag(60)
                    Text("100 Hz").tag(100)
                    Text("120 Hz").tag(120)
                    Text("Unlimited").tag(0)
                }
                Toggle("Send quaternion", isOn: $settings.sendQuaternion)
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
        .padding()
        .frame(width: 380)
    }
}