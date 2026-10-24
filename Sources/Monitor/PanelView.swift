import SwiftUI
import MonitorCore

let monitorAccent = Color(red: 0.34, green: 0.40, blue: 0.94)

struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var settings = false
    @State private var quitHovered = false

    init(model: AppModel, settings: Bool = false) {
        self.model = model
        _settings = State(initialValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if settings { preferences } else { controls }
                }.padding(.vertical, 2)
            }.scrollIndicators(.hidden)
            footer
        }
        .padding(24)
        .frame(width: 420, height: 680)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        .tint(monitorAccent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(monitorAccent.gradient)
                Image(systemName: "display").font(.system(size: 25, weight: .medium)).foregroundStyle(.white)
            }.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Monitor").font(.system(size: 24, weight: .bold, design: .rounded))
                Text(settings ? model.text("Make every adjustment yours.") : model.text("Sound just right. Light just enough."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
            }
            Spacer()
            Button { withAnimation(.easeInOut(duration: 0.15)) { settings.toggle() } } label: {
                Image(systemName: settings ? "arrow.left" : "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium)).frame(width: 32, height: 32)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).fixedSize().accessibilityLabel(settings ? model.text("Controls") : model.text("Settings"))
        }
    }

    @ViewBuilder private var controls: some View {
        if model.scanning {
            VStack(spacing: 14) {
                ProgressView().controlSize(.small)
                Text(model.text("Looking for connected monitors")).font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 240)
        } else if let selected = model.selected {
            HStack(spacing: 9) {
                Image(systemName: "display").foregroundStyle(monitorAccent)
                if model.displays.count > 1 {
                    Picker(model.text("Monitor"), selection: $model.selectedID) {
                        ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                            Text("\(display.name) · \(index + 1)").tag(display.id)
                        }
                    }.labelsHidden()
                } else { Text(selected.name).font(.system(size: 12, weight: .medium)) }
                Spacer()
                Text(model.text("External display")).font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(12).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
            controlCard(.volume, title: model.text("Volume"), symbol: "speaker.wave.2.fill", mode: model.volumeMode)
            controlCard(.brightness, title: model.text("Brightness"), symbol: "sun.max.fill", mode: model.brightnessMode)
            HStack(spacing: 8) {
                Button { model.toggleMute() } label: {
                    Label(selected.levels[.volume]?.current == 0 ? model.text("Unmute") : model.text("Mute"), systemImage: selected.levels[.volume]?.current == 0 ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 11)).frame(maxWidth: .infinity).padding(12)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).disabled(selected.levels[.volume] == nil)
                Button { model.scan() } label: {
                    Label(model.text("Scan again"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11)).frame(maxWidth: .infinity).padding(12)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
            keyboardStatus
        } else {
            VStack(spacing: 14) {
                Image(systemName: "display.trianglebadge.exclamationmark").font(.system(size: 42)).foregroundStyle(monitorAccent.opacity(0.7))
                Text(model.text("Connect your monitor")).font(.system(size: 16, weight: .semibold))
                Text(model.text("Connect a DDC/CI monitor to your Apple Silicon Mac to control volume and brightness."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(model.text("Scan again")) { model.scan() }.buttonStyle(.borderedProminent)
            }.padding(20).frame(maxWidth: .infinity, minHeight: 290)
        }
    }

    private func controlCard(_ control: Control, title: String, symbol: String, mode: AdjustmentMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(title, systemImage: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                if let level = model.selected?.levels[control] {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(level.current)").font(.system(size: 31, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("/ \(level.maximum)").font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
            }
            if let level = model.selected?.levels[control] {
                HStack(spacing: 12) {
                    stepButton(control, up: false, title: title)
                    Slider(value: Binding(get: { Double(model.selected?.levels[control]?.current ?? 0) }, set: { model.set(control, value: Int($0.rounded())) }), in: 0...Double(level.maximum))
                        .accessibilityLabel(title).accessibilityValue("\(level.current)")
                    stepButton(control, up: true, title: title)
                }
                HStack {
                    Text(mode == .fine ? model.text("{0} per press", "1") : model.text("16 steps")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Text(control == .volume ? model.text("Sound, finely tuned") : model.text("Comfort for your eyes")).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            } else {
                Text(model.text("Could not read this control. Check the monitor’s DDC/CI setting and connection."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(16)
            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.065)))
    }

    private func stepButton(_ control: Control, up: Bool, title: String) -> some View {
        Button { model.step(control, up: up) } label: {
            Image(systemName: up ? "plus" : "minus").font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28).background(monitorAccent.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).foregroundStyle(monitorAccent).accessibilityLabel(model.text(up ? "Increase {0}" : "Decrease {0}", title))
    }

    @ViewBuilder private var keyboardStatus: some View {
        if model.conflict {
            note(model.text("MonitorControl is running"), detail: model.text("Quit MonitorControl to let Monitor handle your media keys without conflicts."), symbol: "keyboard.badge.ellipsis")
        } else if !model.trusted && (model.volumeKeys || model.brightnessKeys) {
            VStack(alignment: .leading, spacing: 10) {
                note(model.text("Better with your keyboard"), detail: model.text("Enable Monitor in System Settings → Privacy & Security → Accessibility."), symbol: "keyboard")
                Button(model.text("Open accessibility settings")) { model.openAccessibility() }.buttonStyle(.borderless).font(.system(size: 11))
            }
        } else if (model.volumeKeys || model.brightnessKeys) && !model.keysActive {
            note(model.text("Check the keyboard connection"), detail: model.text("Check Accessibility permission, then restart Monitor. You can use the sliders now."), symbol: "keyboard")
        } else {
            Label(keyboardSummary, systemImage: "keyboard")
                .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 2)
        }
    }
    private func note(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .semibold))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var preferences: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(model.text("Language"), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language == .system ? model.text("Follow system") : language.nativeName).tag(language)
                    }
                }.accessibilityIdentifier("language-picker")
                Text(model.text("Changes apply immediately and stay saved after restarting Monitor."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            modePicker(model.text("Volume adjustment"), selection: $model.volumeMode)
            modePicker(model.text("Brightness adjustment"), selection: $model.brightnessMode)
            Text(model.text("Hold Shift + Option for a 1-unit adjustment in either mode."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Toggle(model.text("Use keyboard volume keys"), isOn: $model.volumeKeys).toggleStyle(.switch)
            Toggle(model.text("Use keyboard brightness keys"), isOn: $model.brightnessKeys).toggleStyle(.switch)
            Text(model.text("Keys control the selected external monitor. Disable brightness keys to keep Mac’s normal brightness control."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            keyboardStatus
            Divider()
            Toggle(model.text("Launch at login"), isOn: Binding(get: { model.loginEnabled }, set: model.setLogin)).toggleStyle(.switch)
            HStack {
                Text("Monitor \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0")").foregroundStyle(.secondary)
                Spacer()
                Link("GitHub ↗", destination: URL(string: "https://github.com/doumAb180/monitor-control")!)
            }.font(.system(size: 11))
        }.font(.system(size: 12))
    }
    private func modePicker(_ title: String, selection: Binding<AdjustmentMode>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(AdjustmentMode.allCases) { mode in
                    Text(model.text(mode == .fine ? "Fine" : "Standard")).tag(mode)
                }
            }.pickerStyle(.segmented).labelsHidden()
            Text(model.text(selection.wrappedValue == .fine ? "Exactly 1 per press." : "16 steps across the range, like macOS volume keys."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: model.isError ? "exclamationmark.circle.fill" : "circle.fill")
                    .font(.system(size: model.isError ? 11 : 6)).foregroundStyle(model.isError ? Color.orange : monitorAccent).padding(.top, 3)
                Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }.frame(minHeight: 28, alignment: .topLeading)
            HStack {
                Text(model.text("Small adjustments. Big comfort."))
                Spacer()
                quitButton
            }.font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private var keyboardSummary: String {
        if model.volumeKeys {
            return model.text("Volume keys · {0}", model.text(model.volumeMode == .fine ? "Fine" : "Standard"))
        }
        if model.brightnessKeys {
            return model.text("Brightness keys · {0}", model.text(model.brightnessMode == .fine ? "Fine" : "Standard"))
        }
        return model.text("Keyboard control is off")
    }

    private var quitButton: some View {
        Button { NSApp.terminate(nil) } label: {
            Label(model.text("Quit Monitor"), systemImage: "power")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.primary)
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(quitHovered ? monitorAccent.opacity(0.14) : .primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.14)))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).onHover { quitHovered = $0 }
            .help(model.text("Quit Monitor")).keyboardShortcut("q", modifiers: .command)
            .accessibilityIdentifier("quit-monitor")
    }
}
