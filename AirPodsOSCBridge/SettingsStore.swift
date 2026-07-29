import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var destinationHost: String { didSet { persistAndNotify() } }
    @Published var destinationPort: Int { didSet { persistAndNotify() } }
    @Published var maximumSendRate: Int { didSet { persistAndNotify() } }
    @Published var sendQuaternion: Bool { didSet { persistAndNotify() } }
    @Published var sendEuler: Bool { didSet { persistAndNotify() } }
    @Published var sendGyroscope: Bool { didSet { persistAndNotify() } }
    @Published var sendAcceleration: Bool { didSet { persistAndNotify() } }
    @Published var quaternionAddress: String { didSet { persistAndNotify() } }
    @Published var eulerAddress: String { didSet { persistAndNotify() } }
    @Published var gyroscopeAddress: String { didSet { persistAndNotify() } }
    @Published var accelerationAddress: String { didSet { persistAndNotify() } }

    var configurationDidChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        destinationHost = defaults.string(forKey: Keys.destinationHost) ?? "127.0.0.1"
        let savedPort = defaults.integer(forKey: Keys.destinationPort)
        destinationPort = savedPort == 0 ? 9000 : savedPort
        let savedRate = defaults.object(forKey: Keys.maximumSendRate) as? Int
        maximumSendRate = savedRate ?? 100
        sendQuaternion = defaults.object(forKey: Keys.sendQuaternion) as? Bool ?? true
        sendEuler = defaults.object(forKey: Keys.sendEuler) as? Bool ?? false
        sendGyroscope = defaults.object(forKey: Keys.sendGyroscope) as? Bool ?? false
        sendAcceleration = defaults.object(forKey: Keys.sendAcceleration) as? Bool ?? false
        quaternionAddress = defaults.string(forKey: Keys.quaternionAddress) ?? OSCAddressDefaults.quaternion
        eulerAddress = defaults.string(forKey: Keys.eulerAddress) ?? OSCAddressDefaults.euler
        gyroscopeAddress = defaults.string(forKey: Keys.gyroscopeAddress) ?? OSCAddressDefaults.gyroscope
        accelerationAddress = defaults.string(forKey: Keys.accelerationAddress) ?? OSCAddressDefaults.acceleration
    }

    var motionConfiguration: MotionConfiguration {
        MotionConfiguration(
            host: destinationHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "127.0.0.1" : destinationHost.trimmingCharacters(in: .whitespacesAndNewlines),
            port: UInt16(clamping: destinationPort),
            maximumSendRate: maximumSendRate == 0 ? nil : Double(maximumSendRate),
            sendQuaternion: sendQuaternion,
            sendEuler: sendEuler,
            sendGyroscope: sendGyroscope,
            sendAcceleration: sendAcceleration,
            quaternionAddress: normalizedAddress(quaternionAddress, defaultValue: OSCAddressDefaults.quaternion),
            eulerAddress: normalizedAddress(eulerAddress, defaultValue: OSCAddressDefaults.euler),
            gyroscopeAddress: normalizedAddress(gyroscopeAddress, defaultValue: OSCAddressDefaults.gyroscope),
            accelerationAddress: normalizedAddress(accelerationAddress, defaultValue: OSCAddressDefaults.acceleration)
        )
    }

    func resetOSCAddresses() {
        quaternionAddress = OSCAddressDefaults.quaternion
        eulerAddress = OSCAddressDefaults.euler
        gyroscopeAddress = OSCAddressDefaults.gyroscope
        accelerationAddress = OSCAddressDefaults.acceleration
    }

    private func persistAndNotify() {
        let defaults = UserDefaults.standard
        defaults.set(destinationHost, forKey: Keys.destinationHost)
        defaults.set(destinationPort, forKey: Keys.destinationPort)
        defaults.set(maximumSendRate, forKey: Keys.maximumSendRate)
        defaults.set(sendQuaternion, forKey: Keys.sendQuaternion)
        defaults.set(sendEuler, forKey: Keys.sendEuler)
        defaults.set(sendGyroscope, forKey: Keys.sendGyroscope)
        defaults.set(sendAcceleration, forKey: Keys.sendAcceleration)
        defaults.set(quaternionAddress, forKey: Keys.quaternionAddress)
        defaults.set(eulerAddress, forKey: Keys.eulerAddress)
        defaults.set(gyroscopeAddress, forKey: Keys.gyroscopeAddress)
        defaults.set(accelerationAddress, forKey: Keys.accelerationAddress)
        configurationDidChange?()
    }

    private func normalizedAddress(_ value: String, defaultValue: String) -> String {
        let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? defaultValue : address
    }
}

private enum OSCAddressDefaults {
    static let quaternion = "/airpods/head/quaternion"
    static let euler = "/airpods/head/euler"
    static let gyroscope = "/airpods/head/gyro"
    static let acceleration = "/airpods/head/accel"
}

private enum Keys {
    static let destinationHost = "destinationHost"
    static let destinationPort = "destinationPort"
    static let maximumSendRate = "maximumSendRate"
    static let sendQuaternion = "sendQuaternion"
    static let sendEuler = "sendEuler"
    static let sendGyroscope = "sendGyroscope"
    static let sendAcceleration = "sendAcceleration"
    static let quaternionAddress = "quaternionAddress"
    static let eulerAddress = "eulerAddress"
    static let gyroscopeAddress = "gyroscopeAddress"
    static let accelerationAddress = "accelerationAddress"
}