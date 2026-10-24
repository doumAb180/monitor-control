import Foundation
import MonitorCore

enum HardwareCheck {
    /// Explicit opt-in diagnostic: one step up and immediately back to the read value.
    static func verifyVolumeStep() -> Bool {
        let devices = DisplayDiscovery.scan()
        guard devices.count == 1, let device = devices.first,
              let before = device.read(.volume), before.current > 0, before.current < before.maximum else {
            print("Needs exactly one readable monitor at a nonzero volume below its maximum.")
            return false
        }
        let target = before.stepped(up: true, by: 1)
        let sent = device.write(.volume, value: target)
        Thread.sleep(forTimeInterval: 0.1)
        let after = device.read(.volume)
        // Restore even when the readback fails; this diagnostic always attempts cleanup.
        let restored = device.write(.volume, value: before.current)
        Thread.sleep(forTimeInterval: 0.1)
        let final = device.read(.volume)
        print("\(device.name): before=\(before.current), requested=\(target), readback=\(after?.current.description ?? "unavailable"), restored=\(final?.current.description ?? "unavailable")")
        return sent && restored && after?.current == target && final?.current == before.current
    }
}
