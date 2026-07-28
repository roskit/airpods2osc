import XCTest
@testable import AirPodsOSCBridge

final class OSCEncoderTests: XCTestCase {
    func testFloatAndIntegerMessageUsesBigEndianValuesAndPadding() {
        let packet = OSCEncoder.message(address: "/test", arguments: [.float(1.0), .int32(42)])
        let expected: [UInt8] = [
            0x2F, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x00,
            0x2C, 0x66, 0x69, 0x00,
            0x3F, 0x80, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x2A
        ]
        XCTAssertEqual(Array(packet), expected)
    }
}