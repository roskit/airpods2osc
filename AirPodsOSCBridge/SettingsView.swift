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
                Toggle("Send Euler angles (radians)", isOn: $settings.sendEuler)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380)
    }
}