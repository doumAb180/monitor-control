import XCTest
@testable import MonitorCore

final class ControlTests: XCTestCase {
    func testOnePressMeansOneHardwareUnit() {
        for maximum in [16, 100, 255] {
            for current in 1..<maximum {
                let level = Level(current: current, maximum: maximum)
                XCTAssertEqual(level.stepped(up: true, by: 1), current + 1)
                XCTAssertEqual(level.stepped(up: false, by: 1), current - 1)
            }
        }
    }
    func testBoundsAndCustomStep() {
        XCTAssertEqual(Level(current: 99, maximum: 100).stepped(up: true, by: 5), 100)
        XCTAssertEqual(Level(current: 1, maximum: 100).stepped(up: false, by: 5), 0)
        XCTAssertEqual(Level(current: 20, maximum: 100).stepped(up: true, by: 2), 22)
    }
    func testWirePackets() {
        XCTAssertEqual(DDCPacket.read(.volume), [0x82, 0x01, 0x62, 0x8f])
        XCTAssertEqual(DDCPacket.write(.volume, value: 21), [0x84, 0x03, 0x62, 0x00, 0x15, 0xcf])
        XCTAssertEqual(DDCPacket.write(.brightness, value: 256)[3...4], [1, 0])
    }
    func testReadReplyValidation() {
        var reply: [UInt8] = [0x6e, 0x88, 0x02, 0x00, 0x62, 0x00, 0x00, 0x64, 0x00, 0x15]
        reply.append(reply.reduce(0x50, ^))
        XCTAssertEqual(DDCPacket.parse(reply, for: .volume), Level(current: 21, maximum: 100))
        XCTAssertNil(DDCPacket.parse(reply, for: .brightness))
        XCTAssertNil(DDCPacket.parse(Array(reply.dropLast()), for: .volume))
        var corrupt = reply; corrupt[9] ^= 1
        XCTAssertNil(DDCPacket.parse(corrupt, for: .volume))
        var unsupported = reply; unsupported[3] = 1; unsupported[10] ^= 1
        XCTAssertNil(DDCPacket.parse(unsupported, for: .volume))
        var outOfRange = reply; outOfRange[9] = 101
        outOfRange[10] = outOfRange.dropLast().reduce(0x50, ^)
        XCTAssertNil(DDCPacket.parse(outOfRange, for: .volume))
    }
}
