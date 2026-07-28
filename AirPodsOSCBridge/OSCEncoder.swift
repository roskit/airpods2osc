import Foundation

enum OSCArgument {
    case float(Float)
    case int32(Int32)

    var typeTag: Character {
        switch self {
        case .float:
            return "f"
        case .int32:
            return "i"
        }
    }
}

enum OSCEncoder {
    static func message(address: String, arguments: [OSCArgument]) -> Data {
        precondition(address.hasPrefix("/"), "OSC addresses must start with '/'.")

        var packet = Data()
        packet.appendPaddedString(address)
        packet.appendPaddedString("," + String(arguments.map(\.typeTag)))

        for argument in arguments {
            switch argument {
            case .float(let value):
                packet.appendBigEndian(value.bitPattern)
            case .int32(let value):
                packet.appendBigEndian(UInt32(bitPattern: value))
            }
        }

        return packet
    }
}

private extension Data {
    mutating func appendPaddedString(_ string: String) {
        append(contentsOf: string.utf8)
        append(0)
        while count % 4 != 0 {
            append(0)
        }
    }

    mutating func appendBigEndian(_ value: UInt32) {
        var bigEndianValue = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndianValue) { append(contentsOf: $0) }
    }
}