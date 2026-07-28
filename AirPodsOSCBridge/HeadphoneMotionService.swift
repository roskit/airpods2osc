import CoreMotion
import Foundation
import os

enum StreamStatus: String, Sendable {
    case unavailable = "Unavailable"
    case permissionNeeded = "Permission Needed"
    case headphonesDisconnected = "Headphones Disconnected"
    case ready = "Ready"
    case streaming = "Streaming"
    case error = "Error"
}

struct MotionConfiguration: Sendable, Equatable {
    let host: String
    let port: UInt16
    let maximumSendRate: Double?
    let sendQuaternion: Bool
    let sendEuler: Bool
}

struct MotionSnapshot: Sendable {
    let status: StreamStatus
    let yaw: Double
    let pitch: Double
    let roll: Double
    let motionAvailable: Bool
    let deviceMotionActive: Bool
    let lastError: String?
}

final class HeadphoneMotionService: @unchecked Sendable {
    // All streaming state is accessed only on motionQueue.
    private let motionManager = CMHeadphoneMotionManager()
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.airpodsoscbridge.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    private let sender = OSCSender()
    private let logger = Logger(subsystem: "com.airpodsoscbridge", category: "Motion")

    private var configuration = MotionConfiguration(
        host: "127.0.0.1",
        port: 9000,
        maximumSendRate: 100,
        sendQuaternion: true,
        sendEuler: true
    )
    private var neutralAttitude: CMAttitude?
    private var isStreaming = false
    private var hasSentStreamingStatus = false
    private var lastPacketDate: TimeInterval = 0
    private var lastSnapshotDate = Date.distantPast

    var snapshotHandler: (@Sendable (MotionSnapshot) -> Void)?
    var senderDiagnosticsHandler: (@Sendable (SenderDiagnostics) -> Void)?

    init() {
        sender.diagnosticsHandler = { [weak self] diagnostics in
            self?.senderDiagnosticsHandler?(diagnostics)
        }
    }

    var isMotionAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    var isDeviceMotionActive: Bool {
        motionManager.isDeviceMotionActive
    }

    func updateConfiguration(_ configuration: MotionConfiguration) {
        motionQueue.addOperation { [weak self] in
            guard let self else { return }
            let destinationChanged = self.configuration.host != configuration.host || self.configuration.port != configuration.port
            self.configuration = configuration
            if self.isStreaming && destinationChanged {
                self.sender.configure(host: configuration.host, port: configuration.port)
            }
        }
    }

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            publish(status: .unavailable, error: "Headphone motion is unavailable. Connect compatible AirPods or headphones.")
            return
        }

        motionQueue.addOperation { [weak self] in
            guard let self, !self.isStreaming else { return }
            self.sender.configure(host: self.configuration.host, port: self.configuration.port)
            self.neutralAttitude = nil
            self.hasSentStreamingStatus = false
            self.lastPacketDate = 0
            self.isStreaming = true

            self.motionManager.startDeviceMotionUpdates(to: self.motionQueue) { [weak self] motion, error in
                guard let self else { return }
                self.process(motion: motion, error: error)
            }
            self.publish(status: .ready, error: nil, force: true)
        }
    }

    func stop() {
        motionQueue.addOperation { [weak self] in
            guard let self else { return }
            let wasStreaming = self.isStreaming
            self.isStreaming = false
            self.motionManager.stopDeviceMotionUpdates()
            if wasStreaming {
                self.sender.sendThenCancel(OSCEncoder.message(address: "/airpods/status", arguments: [.int32(0)]))
            } else {
                self.sender.cancel()
            }
            self.publish(status: self.motionManager.isDeviceMotionAvailable ? .ready : .unavailable, error: nil, force: true)
        }
    }

    func recenter() {
        motionQueue.addOperation { [weak self] in
            guard let self else { return }
            guard let attitude = self.motionManager.deviceMotion?.attitude else {
                self.publish(status: .ready, error: "Waiting for valid headphone motion before recentering.", force: true)
                return
            }
            self.neutralAttitude = attitude.copy() as? CMAttitude
        }
    }

    private func process(motion: CMDeviceMotion?, error: Error?) {
        guard isStreaming else { return }
        if let error {
            isStreaming = false
            sender.send(OSCEncoder.message(address: "/airpods/status", arguments: [.int32(0)]))
            sender.cancel()
            publish(status: .error, error: error.localizedDescription, force: true)
            return
        }
        guard let motion else {
            publish(status: .headphonesDisconnected, error: nil)
            return
        }

        let relativeAttitude = motion.attitude.copy() as! CMAttitude
        if let neutralAttitude {
            relativeAttitude.multiply(byInverseOf: neutralAttitude)
        }

        let now = ProcessInfo.processInfo.systemUptime
        if let maximumSendRate = configuration.maximumSendRate,
           now - lastPacketDate < 1 / maximumSendRate {
            return
        }
        lastPacketDate = now

        if !hasSentStreamingStatus {
            sender.send(OSCEncoder.message(address: "/airpods/status", arguments: [.int32(1)]))
            hasSentStreamingStatus = true
        }

        let quaternion = relativeAttitude.quaternion
        if configuration.sendQuaternion {
            sender.send(OSCEncoder.message(
                address: "/airpods/head/quaternion",
                arguments: [.float(Float(quaternion.w)), .float(Float(quaternion.x)), .float(Float(quaternion.y)), .float(Float(quaternion.z))]
            ))
        }
        if configuration.sendEuler {
            sender.send(OSCEncoder.message(
                address: "/airpods/head/euler",
                arguments: [.float(Float(relativeAttitude.yaw)), .float(Float(relativeAttitude.pitch)), .float(Float(relativeAttitude.roll))]
            ))
        }
        sender.send(OSCEncoder.message(
            address: "/airpods/head/gyro",
            arguments: [.float(Float(motion.rotationRate.x)), .float(Float(motion.rotationRate.y)), .float(Float(motion.rotationRate.z))]
        ))
        sender.send(OSCEncoder.message(
            address: "/airpods/head/accel",
            arguments: [.float(Float(motion.userAcceleration.x)), .float(Float(motion.userAcceleration.y)), .float(Float(motion.userAcceleration.z))]
        ))

        publish(
            status: .streaming,
            yaw: relativeAttitude.yaw,
            pitch: relativeAttitude.pitch,
            roll: relativeAttitude.roll,
            error: nil
        )
    }

    private func publish(
        status: StreamStatus,
        yaw: Double = 0,
        pitch: Double = 0,
        roll: Double = 0,
        error: String?,
        force: Bool = false
    ) {
        guard force || Date().timeIntervalSince(lastSnapshotDate) >= 0.1 else { return }
        lastSnapshotDate = Date()
        if let error {
            logger.error("Motion service error: \(error, privacy: .public)")
        }
        snapshotHandler?(MotionSnapshot(
            status: status,
            yaw: yaw,
            pitch: pitch,
            roll: roll,
            motionAvailable: motionManager.isDeviceMotionAvailable,
            deviceMotionActive: motionManager.isDeviceMotionActive,
            lastError: error
        ))
    }
}