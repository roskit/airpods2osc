import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var status: StreamStatus
    @Published private(set) var yaw: Double = 0
    @Published private(set) var pitch: Double = 0
    @Published private(set) var roll: Double = 0
    @Published private(set) var motionAvailable: Bool
    @Published private(set) var deviceMotionActive = false
    @Published private(set) var packetCount: UInt64 = 0
    @Published private(set) var measuredSendRate: Double = 0
    @Published private(set) var lastError: String?

    let settings = SettingsStore()
    private let motionService = HeadphoneMotionService()
    private var lastPacketCount: UInt64 = 0
    private var lastRateMeasurement = Date()
    private var resumeAfterActive = false

    init() {
        let availableMotion = motionService.isMotionAvailable
        motionAvailable = availableMotion
        status = availableMotion ? .ready : .unavailable

        settings.configurationDidChange = { [weak self] in
            guard let self else { return }
            self.motionService.updateConfiguration(self.settings.motionConfiguration)
        }
        motionService.snapshotHandler = { [weak self] snapshot in
            Task { @MainActor [weak self] in self?.apply(snapshot) }
        }
        motionService.senderDiagnosticsHandler = { [weak self] diagnostics in
            Task { @MainActor [weak self] in self?.apply(diagnostics) }
        }
        motionService.updateConfiguration(settings.motionConfiguration)
    }

    var isStreaming: Bool { status == .streaming || deviceMotionActive }

    func start() {
        lastError = nil
        motionService.start()
    }

    func stop() {
        motionService.stop()
    }

    func recenter() {
        motionService.recenter()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            resumeAfterActive = isStreaming
            if resumeAfterActive { stop() }
        case .active:
            if resumeAfterActive {
                resumeAfterActive = false
                start()
            }
        @unknown default:
            break
        }
    }

    private func apply(_ snapshot: MotionSnapshot) {
        status = snapshot.status
        yaw = snapshot.yaw
        pitch = snapshot.pitch
        roll = snapshot.roll
        motionAvailable = snapshot.motionAvailable
        deviceMotionActive = snapshot.deviceMotionActive
        if let error = snapshot.lastError { lastError = error }
    }

    private func apply(_ diagnostics: SenderDiagnostics) {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRateMeasurement)
        if elapsed > 0 {
            measuredSendRate = Double(diagnostics.packetCount - lastPacketCount) / elapsed
        }
        packetCount = diagnostics.packetCount
        lastPacketCount = diagnostics.packetCount
        lastRateMeasurement = now
        if let error = diagnostics.lastError { lastError = error }
    }
}