public enum Control: UInt8, CaseIterable, Hashable, Sendable {
    case volume = 0x62
    case brightness = 0x10
}

public struct Level: Equatable, Sendable {
    public var current: Int
    public let maximum: Int
    public init(current: Int, maximum: Int) {
        self.maximum = max(1, maximum)
        self.current = min(max(0, current), self.maximum)
    }
    public func stepped(up: Bool, by step: Int) -> Int {
        min(maximum, max(0, current + (up ? 1 : -1) * max(1, step)))
    }
}

// DDC/CI framing and IOAV checksum convention documented by MonitorControl.
// See THIRD_PARTY_NOTICES.md. No MonitorControl app or dependency is required.
public enum DDCPacket {
    public static func read(_ control: Control) -> [UInt8] {
        let body: [UInt8] = [0x82, 0x01, control.rawValue]
        return body + [body.reduce(0x6e, ^)]
    }
    public static func write(_ control: Control, value: UInt16) -> [UInt8] {
        let body: [UInt8] = [0x84, 0x03, control.rawValue, UInt8(value >> 8), UInt8(value & 255)]
        return body + [body.reduce(0x6e ^ 0x51, ^)]
    }
    public static func parse(_ reply: [UInt8], for control: Control) -> Level? {
        guard reply.count == 11, reply[0] == 0x6e, reply[1] == 0x88,
              reply[2] == 0x02, reply[3] == 0, reply[4] == control.rawValue,
              reply.reduce(UInt8(0x50), ^) == 0 else { return nil }
        let maximum = Int(reply[6]) * 256 + Int(reply[7])
        let current = Int(reply[8]) * 256 + Int(reply[9])
        guard maximum > 0, current <= maximum else { return nil }
        return Level(current: current, maximum: maximum)
    }
}
