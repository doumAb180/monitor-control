import AppKit
import ApplicationServices
import MonitorCore

final class MediaKeys {
    enum Action { case adjust(Control, Bool), mute }
    var accepts: ((Action) -> Bool)?
    var perform: ((Action, Bool) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var active: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let keys = Unmanaged<MediaKeys>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = keys.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined,
                  ns.subtype.rawValue == 8,
                  !ns.modifierFlags.contains(.command), !ns.modifierFlags.contains(.control) else {
                return Unmanaged.passUnretained(event)
            }
            let code = (ns.data1 >> 16) & 0xffff
            let state = (ns.data1 >> 8) & 0xff
            let action: Action
            switch code {
            case 0: action = .adjust(.volume, true)
            case 1: action = .adjust(.volume, false)
            case 7: action = .mute
            case 2: action = .adjust(.brightness, true)
            case 3: action = .adjust(.brightness, false)
            default: return Unmanaged.passUnretained(event)
            }
            guard keys.accepts?(action) == true else { return Unmanaged.passUnretained(event) }
            if state == 0x0a {
                let repeating = ns.data1 & 1 != 0
                if case .mute = action, repeating { return nil }
                let fine = ns.modifierFlags.contains([.option, .shift])
                keys.perform?(action, fine)
            }
            return nil
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: 1 << 14, // NX_SYSDEFINED
            callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil; tap = nil
    }
    deinit { stop() }
}
