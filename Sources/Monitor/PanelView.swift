import SwiftUI
import MonitorCore

let monitorAccent = Color(red: 0.34, green: 0.40, blue: 0.94)

struct PanelView: View {
    @ObservedObject var model: AppModel
    @State private var settings = false

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
                Text(settings ? "작은 차이도, 내 취향대로." : "딱 맞는 소리, 편안한 밝기.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { withAnimation(.easeInOut(duration: 0.15)) { settings.toggle() } } label: {
                Image(systemName: settings ? "arrow.left" : "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium)).frame(width: 32, height: 32)
                    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).accessibilityLabel(settings ? "조절 화면" : "설정")
        }
    }

    @ViewBuilder private var controls: some View {
        if model.scanning {
            VStack(spacing: 14) {
                ProgressView().controlSize(.small)
                Text("연결된 모니터를 찾고 있어요").font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, minHeight: 240)
        } else if let selected = model.selected {
            HStack(spacing: 9) {
                Image(systemName: "display").foregroundStyle(monitorAccent)
                if model.displays.count > 1 {
                    Picker("모니터", selection: $model.selectedID) {
                        ForEach(Array(model.displays.enumerated()), id: \.element.id) { index, display in
                            Text("\(display.name) · \(index + 1)").tag(display.id)
                        }
                    }.labelsHidden()
                } else { Text(selected.name).font(.system(size: 12, weight: .medium)) }
                Spacer()
                Text("외부 모니터").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(12).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
            controlCard(.volume, title: "볼륨", symbol: "speaker.wave.2.fill", step: model.volumeStep)
            controlCard(.brightness, title: "밝기", symbol: "sun.max.fill", step: model.brightnessStep)
            HStack(spacing: 8) {
                Button { model.toggleMute() } label: {
                    Label(selected.levels[.volume]?.current == 0 ? "음소거 해제" : "음소거", systemImage: selected.levels[.volume]?.current == 0 ? "speaker.wave.2" : "speaker.slash")
                        .font(.system(size: 11)).frame(maxWidth: .infinity).padding(12)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).disabled(selected.levels[.volume] == nil)
                Button { model.scan() } label: {
                    Label("다시 검색", systemImage: "arrow.clockwise")
                        .font(.system(size: 11)).frame(maxWidth: .infinity).padding(12)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }
            keyboardStatus
        } else {
            VStack(spacing: 14) {
                Image(systemName: "display.trianglebadge.exclamationmark").font(.system(size: 42)).foregroundStyle(monitorAccent.opacity(0.7))
                Text("모니터를 연결해 주세요").font(.system(size: 16, weight: .semibold))
                Text("Apple Silicon Mac에서 DDC/CI를 지원하는 외부 모니터를 연결하면 볼륨과 밝기를 조절할 수 있어요.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("다시 검색") { model.scan() }.buttonStyle(.borderedProminent)
            }.padding(20).frame(maxWidth: .infinity, minHeight: 290)
        }
    }

    private func controlCard(_ control: Control, title: String, symbol: String, step: Int) -> some View {
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
                    Text("한 번에 \(step)씩").font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    Text(control == .volume ? "소리도 섬세하게" : "눈이 편안한 만큼").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            } else {
                Text("이 모니터에서 값을 읽지 못했어요. 모니터의 DDC/CI 설정과 연결을 확인해 주세요.")
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
        }.buttonStyle(.plain).foregroundStyle(monitorAccent).accessibilityLabel(title + (up ? " 높이기" : " 낮추기"))
    }

    @ViewBuilder private var keyboardStatus: some View {
        if model.conflict {
            note("MonitorControl이 실행 중이에요", detail: "키보드 제어가 겹치지 않도록 MonitorControl을 종료하면 Monitor가 볼륨 키를 연결해요.", symbol: "keyboard.badge.ellipsis")
        } else if !model.trusted && (model.volumeKeys || model.brightnessKeys) {
            VStack(alignment: .leading, spacing: 10) {
                note("키보드로 더 편하게", detail: "시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 Monitor를 허용해 주세요.", symbol: "keyboard")
                Button("손쉬운 사용 설정 열기") { model.openAccessibility() }.buttonStyle(.borderless).font(.system(size: 11))
            }
        } else if (model.volumeKeys || model.brightnessKeys) && !model.keysActive {
            note("키보드 연결을 확인해 주세요", detail: "손쉬운 사용 권한을 확인한 뒤 Monitor를 다시 실행해 주세요. 슬라이더는 바로 사용할 수 있어요.", symbol: "keyboard")
        } else {
            Label(model.volumeKeys ? "볼륨 키 · 한 번에 \(model.volumeStep)씩" : "키보드 제어 꺼짐", systemImage: "keyboard")
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
            stepPicker("볼륨 조절 간격", selection: $model.volumeStep)
            stepPicker("밝기 조절 간격", selection: $model.brightnessStep)
            Text("모니터의 실제 숫자를 기준으로 조절해요. Shift + Option을 누르면 언제나 1씩 움직여요.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Toggle("키보드 볼륨 키 사용", isOn: $model.volumeKeys).toggleStyle(.switch)
            Toggle("키보드 밝기 키 사용", isOn: $model.brightnessKeys).toggleStyle(.switch)
            Text("선택한 외부 모니터에 적용돼요. 밝기 키를 끄면 Mac의 기본 밝기 조절을 유지해요.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            keyboardStatus
            Divider()
            Toggle("로그인할 때 실행", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin)).toggleStyle(.switch)
            HStack {
                Text("Monitor \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")").foregroundStyle(.secondary)
                Spacer()
                Link("GitHub ↗", destination: URL(string: "https://github.com/doumAb180/monitor-control")!)
            }.font(.system(size: 11))
        }.font(.system(size: 12))
    }
    private func stepPicker(_ title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach([1, 2, 5, 10], id: \.self) { Text("\($0)").tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
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
                Text("작은 조절, 큰 편안함.")
                Spacer()
                Button("종료") { NSApp.terminate(nil) }.buttonStyle(.plain)
            }.font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}
