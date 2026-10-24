import AppKit
import SwiftUI
import MonitorCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var model: AppModel!
    private var hud: NSPanel?
    private var dismissHUD: DispatchWorkItem?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier, NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil); return
        }
        model = AppModel()
        model.onAdjustment = { [weak self] name, symbol, value, maximum in self?.showHUD(name, symbol, value, maximum) }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Monitor")
        item.button?.toolTip = model.text("Monitor · Volume and brightness")
        model.onLanguageChange = { [weak self] in
            guard let self else { return }
            self.item.button?.toolTip = self.model.text("Monitor · Volume and brightness")
            self.item.button?.setAccessibilityLabel(self.model.text("Monitor · Volume and brightness"))
        }
        item.button?.target = self; item.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PanelView(model: model))
        if !UserDefaults.standard.bool(forKey: "hasLaunched") {
            UserDefaults.standard.set(true, forKey: "hasLaunched")
            toggle()
        }
    }
    @objc private func toggle() {
        guard let button = item.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            model.refreshKeyboard()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    private func showHUD(_ name: String, _ symbol: String, _ value: Int, _ maximum: Int) {
        guard !popover.isShown else { return }
        dismissHUD?.cancel(); hud?.orderOut(nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 82), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: VStack(spacing: 10) {
            HStack {
                Image(systemName: value == 0 && symbol.contains("speaker") ? "speaker.slash.fill" : symbol).foregroundStyle(monitorAccent)
                Text(name).font(.system(size: 11)).lineLimit(1)
                Spacer()
                Text("\(value)").font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            ProgressView(value: Double(value), total: Double(maximum)).tint(monitorAccent)
        }.padding(16).frame(width: 280, height: 82).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)))
        if let frame = (NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - 140, y: frame.minY + 50))
        }
        panel.orderFrontRegardless(); hud = panel
        let work = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        dismissHUD = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}

if CommandLine.arguments.contains("--verify-volume-step") {
    exit(HardwareCheck.verifyVolumeStep() ? 0 : 1)
} else if CommandLine.arguments.contains("--probe") {
    // Read-only hardware diagnostic; no settings or monitor values are changed.
    let devices = DisplayDiscovery.scan()
    print("DDC displays: \(devices.count)")
    for device in devices {
        print(device.name)
        for control in Control.allCases {
            if let level = device.read(control) { print("  \(control): \(level.current)/\(level.maximum)") }
            else { print("  \(control): unavailable") }
        }
    }
} else if let index = CommandLine.arguments.firstIndex(of: "--render-preview"), CommandLine.arguments.count > index + 1 {
    _ = NSApplication.shared
    let path = CommandLine.arguments[index + 1]
    try MainActor.assumeIsolated {
        let model = AppModel(preview: true)
        if let index = CommandLine.arguments.firstIndex(of: "--language"), CommandLine.arguments.count > index + 1 {
            model.language = AppLanguage(rawValue: CommandLine.arguments[index + 1]) ?? .english
        }
        let dark = CommandLine.arguments.contains("--dark")
        let view = NSHostingView(rootView: PanelView(model: model, settings: CommandLine.arguments.contains("--settings")).environment(\.colorScheme, dark ? .dark : .light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 680), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = view
        view.frame = NSRect(x: 0, y: 0, width: 420, height: 680)
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.setActivationPolicy(.accessory); app.delegate = delegate
    app.run()
}
