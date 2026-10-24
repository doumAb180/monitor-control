import AppKit
import SwiftUI
import ApplicationServices
import ServiceManagement
import MonitorCore

struct DisplayState: Identifiable {
    let id: String
    let name: String
    var levels: [Control: Level]
}

final class AppModel: ObservableObject {
    @Published var displays: [DisplayState] = []
    @Published var selectedID: String {
        didSet { if !preview { defaults.set(selectedID, forKey: "selectedDisplay") } }
    }
    @Published var scanning = false
    @Published private var messageText: LocalizedText = .key("Looking for your monitor…")
    var message: String { messageText.rendered(in: language) }
    @Published var language: AppLanguage {
        didSet {
            if !preview { defaults.set(language.rawValue, forKey: "appLanguage.v1") }
            onLanguageChange?()
        }
    }
    var onLanguageChange: (() -> Void)?
    func text(_ key: String, _ arguments: String...) -> String {
        LocalizedText.key(key, arguments.map { .verbatim($0) }).rendered(in: language)
    }
    @Published var isError = false
    @Published var trusted = AXIsProcessTrusted()
    @Published var keysActive = false
    @Published var conflict = false
    @Published var volumeMode: AdjustmentMode {
        didSet { if !preview { defaults.set(volumeMode.rawValue, forKey: "volumeMode.v1") } }
    }
    @Published var brightnessMode: AdjustmentMode {
        didSet { if !preview { defaults.set(brightnessMode.rawValue, forKey: "brightnessMode.v1") } }
    }
    @Published var volumeKeys: Bool {
        didSet { if !preview { defaults.set(volumeKeys, forKey: "volumeKeys"); refreshKeyboard() } }
    }
    @Published var brightnessKeys: Bool {
        didSet { if !preview { defaults.set(brightnessKeys, forKey: "brightnessKeys"); refreshKeyboard() } }
    }
    @Published var loginEnabled = false
    var onAdjustment: ((String, String, Int, Int) -> Void)?
    let preview: Bool
    private let defaults: UserDefaults
    private let connectHardware: Bool
    private let io = DispatchQueue(label: "io.github.doumAb180.Monitor.ddc")
    private var devices: [String: DisplayDevice] = [:]
    private var generation = 0
    private var pending: [String: DispatchWorkItem] = [:]
    private var tickets: [String: WriteTicket] = [:]
    private var revisions: [String: Int] = [:]
    private var previousVolume: [String: Int] = [:]
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private let keys = MediaKeys()
    private var rescanWork: DispatchWorkItem?

    var selected: DisplayState? { displays.first { $0.id == selectedID } }

    init(preview: Bool = false, defaults: UserDefaults = .standard, connectHardware: Bool = true) {
        self.preview = preview
        self.defaults = defaults
        self.connectHardware = connectHardware
        language = AppLanguage(rawValue: defaults.string(forKey: "appLanguage.v1") ?? "system") ?? .system
        selectedID = defaults.string(forKey: "selectedDisplay") ?? ""
        volumeMode = AdjustmentMode(rawValue: defaults.string(forKey: "volumeMode.v1") ?? "") ?? (defaults.integer(forKey: "volumeStep") > 1 ? .standard : .fine)
        brightnessMode = AdjustmentMode(rawValue: defaults.string(forKey: "brightnessMode.v1") ?? "") ?? (defaults.integer(forKey: "brightnessStep") > 1 ? .standard : .fine)
        volumeKeys = defaults.object(forKey: "volumeKeys") as? Bool ?? true
        brightnessKeys = defaults.bool(forKey: "brightnessKeys")
        if preview {
            displays = [.init(id: "preview", name: "LG HDR 4K", levels: [.volume: Level(current: 21, maximum: 100), .brightness: Level(current: 65, maximum: 100)])]
            selectedID = "preview"; trusted = true; keysActive = true
            messageText = .key("One step at a time. Just right."); return
        }
        guard connectHardware else { return }
        loginEnabled = SMAppService.mainApp.status == .enabled
        keys.accepts = { [weak self] action in
            guard let self, !self.scanning, !self.conflict, let selected = self.selected else { return false }
            switch action {
            case .mute: return self.volumeKeys && selected.levels[.volume] != nil
            case let .adjust(control, _):
                return (control == .volume ? self.volumeKeys : self.brightnessKeys) && selected.levels[control] != nil
            }
        }
        keys.perform = { [weak self] action, fine in
            switch action {
            case .mute: self?.toggleMute()
            case let .adjust(control, up): self?.step(control, up: up, fine: fine)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshKeyboard() }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleScan() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.scheduleScan() })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.invalidate() })
        refreshKeyboard(); scan()
    }

    private func invalidate() {
        generation += 1
        pending.values.forEach { $0.cancel() }; pending.removeAll()
        tickets.values.forEach { $0.cancel() }; tickets.removeAll()
        devices.removeAll(); displays = []; keys.stop(); keysActive = false
    }
    private func scheduleScan() {
        invalidate(); rescanWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scan() }
        rescanWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }
    func scan() {
        guard !preview, connectHardware else { return }
        invalidate(); scanning = true; messageText = .key("Checking your monitor…"); isError = false
        let epoch = generation
        io.async { [weak self] in
            let found = DisplayDiscovery.scan()
            let states = found.map { device in
                DisplayState(id: device.id, name: device.name, levels: Dictionary(uniqueKeysWithValues: Control.allCases.compactMap { control in device.read(control).map { (control, $0) } }))
            }
            DispatchQueue.main.async {
                guard let self, self.generation == epoch else { return }
                self.devices = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
                self.displays = states; self.scanning = false
                if !states.contains(where: { $0.id == self.selectedID }) { self.selectedID = states.first?.id ?? "" }
                self.messageText = .key(states.isEmpty ? "No DDC monitor found." : "One step at a time. Just right.")
                self.refreshKeyboard()
            }
        }
    }
    func step(_ control: Control, up: Bool, fine: Bool = false) {
        guard let level = selected?.levels[control] else { return }
        let mode: AdjustmentMode = fine ? .fine : (control == .volume ? volumeMode : brightnessMode)
        set(control, value: level.stepped(up: up, mode: mode), showHUD: true)
    }
    func toggleMute() {
        guard let level = selected?.levels[.volume] else { return }
        if level.current > 0 {
            previousVolume[selectedID] = level.current
            set(.volume, value: 0, showHUD: true)
        } else if let previous = previousVolume[selectedID] {
            set(.volume, value: previous, showHUD: true)
        } else {
            set(.volume, value: 1, showHUD: true)
        }
    }
    func set(_ control: Control, value: Int, showHUD: Bool = false) {
        guard !scanning, let index = displays.firstIndex(where: { $0.id == selectedID }),
              let level = displays[index].levels[control] else { return }
        let value = min(level.maximum, max(0, value))
        guard value != level.current else { return }
        if preview { displays[index].levels[control]?.current = value; return }
        guard let device = devices[selectedID] else { return }
        let id = selectedID, key = id + "-\(control.rawValue)", epoch = generation
        let revision = (revisions[key] ?? 0) + 1
        revisions[key] = revision
        displays[index].levels[control]?.current = value
        isError = false
        messageText = .key("Applying {0} {1}…", [.key(control == .volume ? "Volume" : "Brightness"), .verbatim(String(value))])
        if showHUD { onAdjustment?(device.name, control == .volume ? "speaker.wave.2.fill" : "sun.max.fill", value, level.maximum) }
        pending[key]?.cancel()
        tickets[key]?.cancel()
        let ticket = WriteTicket()
        tickets[key] = ticket
        // Debounce on main, then enqueue I/O. Never build an unbounded write queue
        // from slider motion. In-flight results are guarded by epoch + revision.
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.io.async {
                guard !ticket.isCancelled else { return }
                let sent = device.write(control, value: value)
                guard !ticket.isCancelled else { return }
                Thread.sleep(forTimeInterval: 0.05)
                let actual = device.read(control)
                DispatchQueue.main.async {
                    guard self.generation == epoch, self.revisions[key] == revision,
                          let index = self.displays.firstIndex(where: { $0.id == id }) else { return }
                    self.pending.removeValue(forKey: key)
                    self.tickets.removeValue(forKey: key)
                    if let actual {
                        self.displays[index].levels[control] = actual
                        self.isError = !sent || actual.current != value
                        self.messageText = self.isError ? .key("The monitor did not apply the requested value. Please check again.") : .key("{0} {1} · Applied", [.key(control == .volume ? "Volume" : "Brightness"), .verbatim(String(actual.current))])
                    } else {
                        self.displays[index].levels.removeValue(forKey: control)
                        self.isError = true
                        self.messageText = .key("No response from the monitor. Please scan again.")
                    }
                }
            }
        }
        pending[key] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }
    func refreshKeyboard() {
        guard !preview, connectHardware else { return }
        trusted = AXIsProcessTrusted()
        conflict = !NSRunningApplication.runningApplications(withBundleIdentifier: "app.monitorcontrol.MonitorControl").isEmpty
        if trusted && !conflict && !scanning && (volumeKeys || brightnessKeys) {
            keysActive = keys.start()
        } else { keys.stop(); keysActive = false }
    }
    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { messageText = .key("Allow Monitor in System Settings → General → Login Items.") }
        } catch { isError = true; messageText = .key("Could not change the login item: {0}", [.verbatim(error.localizedDescription)]) }
    }
}
