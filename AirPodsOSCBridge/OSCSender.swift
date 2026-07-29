import Foundation
import Network
import os

struct SenderDiagnostics: Sendable {
    let packetCount: UInt64
    let lastSendDate: Date?
    let lastError: String?
}

final class OSCSender: @unchecked Sendable {
    // All mutable state is accessed only on queue.
    private let queue = DispatchQueue(label: "com.airpodsoscbridge.osc-sender", qos: .userInitiated)
    private let logger = Logger(subsystem: "com.airpodsoscbridge", category: "OSC")

    private var connection: NWConnection?
    private var destination: Destination?
    private var packetCount: UInt64 = 0
    private var lastSendDate: Date?
    private var lastError: String?
    private var lastDiagnosticsDate = Date.distantPast

    var diagnosticsHandler: (@Sendable (SenderDiagnostics) -> Void)?

    func configure(host: String, port: UInt16) {
        queue.async { [weak self] in
            self?.configureLocked(host: host, port: port)
        }
    }

    func send(_ data: Data) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let connection = self.connection else {
                self.startConnectionIfNeeded()
                return
            }

            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                self.queue.async {
                    if let error {
                        self.handleSendError(error, for: connection)
                    } else {
                        self.packetCount &+= 1
                        self.lastSendDate = Date()
                    }
                    self.publishDiagnosticsIfNeeded()
                }
            })
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.connection?.cancel()
            self?.connection = nil
            self?.destination = nil
            self?.publishDiagnostics(force: true)
        }
    }

    func sendThenCancel(_ data: Data) {
        queue.async { [weak self] in
            guard let self else { return }
            guard let connection = self.connection else {
                self.destination = nil
                return
            }

            connection.send(content: data, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                self.queue.async {
                    if let error {
                        self.handleSendError(error, for: connection)
                    } else {
                        self.packetCount &+= 1
                        self.lastSendDate = Date()
                    }
                    connection.cancel()
                    self.connection = nil
                    self.destination = nil
                    self.publishDiagnostics(force: true)
                }
            })
        }
    }

    private func configureLocked(host: String, port: UInt16) {
        let newDestination = Destination(host: host, port: port)
        guard destination != newDestination else { return }

        connection?.cancel()
        destination = newDestination
        lastError = nil

        startConnectionIfNeeded()
    }

    private func startConnectionIfNeeded() {
        guard connection == nil, let destination else { return }

        let connection = NWConnection(
            host: NWEndpoint.Host(destination.host),
            port: NWEndpoint.Port(rawValue: destination.port)!,
            using: .udp
        )
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            self.queue.async {
                if case .failed(let error) = state {
                    guard self.connection === connection else { return }
                    if self.isConnectionRefused(error) {
                        self.connection = nil
                        return
                    }
                    self.lastError = error.localizedDescription
                    self.logger.error("OSC connection failed: \(error.localizedDescription, privacy: .public)")
                    self.publishDiagnostics(force: true)
                }
            }
        }
        self.connection = connection
        connection.start(queue: queue)
    }

    private func handleSendError(_ error: NWError, for connection: NWConnection) {
        if isConnectionRefused(error) {
            if self.connection === connection {
                self.connection = nil
            }
            return
        }
        lastError = error.localizedDescription
        logger.error("OSC UDP send failed: \(error.localizedDescription, privacy: .public)")
    }

    private func isConnectionRefused(_ error: NWError) -> Bool {
        if case .posix(.ECONNREFUSED) = error {
            return true
        }
        return false
    }

    private func publishDiagnosticsIfNeeded() {
        guard Date().timeIntervalSince(lastDiagnosticsDate) >= 0.25 else { return }
        publishDiagnostics(force: true)
    }

    private func publishDiagnostics(force: Bool) {
        guard force else { return }
        lastDiagnosticsDate = Date()
        diagnosticsHandler?(SenderDiagnostics(
            packetCount: packetCount,
            lastSendDate: lastSendDate,
            lastError: lastError
        ))
    }
}

private struct Destination: Equatable {
    let host: String
    let port: UInt16
}