import Foundation
import IOKit
import DDCBridge
import MonitorCore

final class DisplayDevice: Identifiable {
    let id: String
    let name: String
    let registryID: UInt64
    private let service: UnsafeMutableRawPointer
    init?(id: String, name: String, registryID: UInt64) {
        guard let service = monitor_ddc_open(registryID) else { return nil }
        self.id = id; self.name = name; self.registryID = registryID; self.service = service
    }
    deinit { monitor_ddc_close(service) }

    // All calls are serialized on the controller's I/O queue, never in a key callback.
    func read(_ control: Control) -> Level? {
        for _ in 0..<3 {
            let request = DDCPacket.read(control)
            guard monitor_ddc_send(service, request, UInt32(request.count)) else {
                Thread.sleep(forTimeInterval: 0.04); continue
            }
            Thread.sleep(forTimeInterval: 0.05)
            var reply = [UInt8](repeating: 0, count: 11)
            if monitor_ddc_receive(service, &reply, UInt32(reply.count)),
               let level = DDCPacket.parse(reply, for: control) { return level }
        }
        return nil
    }
    func write(_ control: Control, value: Int) -> Bool {
        let packet = DDCPacket.write(control, value: UInt16(clamping: value))
        var success = false
        // Some monitors drop the first write; repeat the same absolute value.
        for _ in 0..<2 {
            Thread.sleep(forTimeInterval: 0.01)
            success = monitor_ddc_send(service, packet, UInt32(packet.count)) || success
        }
        return success
    }
}

enum DisplayDiscovery {
    static func scan() -> [DisplayDevice] {
        #if !arch(arm64)
        return []
        #else
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        defer { IOObjectRelease(root) }
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(root, kIOServicePlane, IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var devices: [DisplayDevice] = []
        var product = "External display"
        var identity = ""
        // On Apple Silicon framebuffer metadata precedes the corresponding DCP
        // service in the IOService traversal (see MonitorControl Arm64DDC).
        // The exact service ID is retained for writes; no screen index guessing.
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var buffer = [CChar](repeating: 0, count: 128)
            guard IORegistryEntryGetName(entry, &buffer) == KERN_SUCCESS else { continue }
            let name = String(cString: buffer)
            if name == "AppleCLCD2" || name == "IOMobileFramebufferShim" {
                let attrs = property(entry, "DisplayAttributes") as? [String: Any]
                let details = attrs?["ProductAttributes"] as? [String: Any]
                product = details?["ProductName"] as? String ?? "External display"
                identity = (property(entry, "EDID UUID") as? String ?? "") + ":" + String(describing: details?["SerialNumber"] ?? "")
            }
            guard name == "DCPAVServiceProxy", property(entry, "Location") as? String == "External" else { continue }
            var registryID: UInt64 = 0
            IORegistryEntryGetRegistryEntryID(entry, &registryID)
            var path = [CChar](repeating: 0, count: 512)
            IORegistryEntryGetPath(entry, kIOServicePlane, &path)
            let id = identity + ":" + String(cString: path)
            if let device = DisplayDevice(id: id, name: product, registryID: registryID) { devices.append(device) }
        }
        return devices
        #endif
    }
    private static func property(_ entry: io_registry_entry_t, _ name: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, name as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
