import XCTest
import MonitorCore
@testable import Monitor

private final class FakeDevice: MonitorDevice {
    let id = "test-monitor"
    let name = "Test monitor"
    private let lock = NSLock()
    private var values: [Control: Level] = [.volume: Level(current: 10, maximum: 100), .brightness: Level(current: 70, maximum: 100)]
    private var failures = 0
    private var writes: [(Control, Int)] = []
    private var reads: [Control: Int] = [:]
    private var nextVolumeRead: (() -> Level?)?

    var volumeWrites: [Int] { lock.withLock { writes.filter { $0.0 == .volume }.map { $0.1 } } }
    var brightnessReads: Int { lock.withLock { reads[.brightness, default: 0] } }
    func failVolumeReads(_ count: Int) { lock.withLock { failures = count } }
    func interceptNextVolumeRead(_ callback: @escaping () -> Level?) { lock.withLock { nextVolumeRead = callback } }
    func read(_ control: Control) -> Level? {
        lock.lock()
        reads[control, default: 0] += 1
        if control == .volume, let callback = nextVolumeRead {
            nextVolumeRead = nil
            lock.unlock()
            return callback()
        }
        if control == .volume, failures > 0 {
            failures -= 1
            lock.unlock()
            return nil
        }
        let value = values[control]
        lock.unlock()
        return value
    }
    func write(_ control: Control, value: Int) -> Bool {
        lock.withLock {
            writes.append((control, value))
            values[control]?.current = value
        }
        return true
    }
}

private final class FakeDiscovery {
    private let lock = NSLock()
    private var count = 0
    private var times: [TimeInterval] = []
    private var results: [[any MonitorDevice]]
    init(_ results: [[any MonitorDevice]]) { self.results = results }
    var calls: Int { lock.withLock { count } }
    var callTimes: [TimeInterval] { lock.withLock { times } }
    func scan() -> [any MonitorDevice] {
        lock.withLock {
            let result = results[min(count, results.count - 1)]
            count += 1
            times.append(ProcessInfo.processInfo.systemUptime)
            return result
        }
    }
}

final class RecoveryTests: XCTestCase {
    private var suites: [String] = []
    override func tearDown() {
        for suite in suites { UserDefaults.standard.removePersistentDomain(forName: suite) }
        suites.removeAll()
        super.tearDown()
    }
    private func model(_ source: FakeDiscovery, delays: [TimeInterval] = [0.03, 0.06, 0.1]) -> AppModel {
        let suite = "RecoveryTests.\(UUID().uuidString)"
        suites.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        defaults.register(defaults: ["appLanguage.v1": "en"])
        return AppModel(defaults: defaults, connectHardware: false, discovery: source.scan, recoveryDelays: delays)
    }
    private func eventually(_ description: String, timeout: TimeInterval = 3, file: StaticString = #filePath,
                            line: UInt = #line, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.005)) }
        XCTAssertTrue(condition(), description, file: file, line: line)
    }
    private func runLoop(for duration: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(duration)) }

    func testFailedReadbackKeepsKeysAndRecoversWithoutReplayingWrite() {
        let old = FakeDevice(), reopened = FakeDevice()
        let source = FakeDiscovery([[old], [reopened]])
        let model = model(source, delays: [0.15])
        defer { model.prepareForSleep() }
        model.scan()
        eventually("initial scan") { !model.scanning && model.selected != nil }
        old.failVolumeReads(1)
        model.step(.volume, up: true)
        eventually("failed readback") { model.isError }
        XCTAssertEqual(model.selected?.levels[.volume]?.current, 11)
        XCTAssertTrue(model.accepts(.adjust(.volume, true)))
        XCTAssertTrue(model.accepts(.mute))
        XCTAssertNotNil(model.selected?.levels[.brightness])
        eventually("automatic read restores actual hardware value") {
            source.calls == 2 && model.selected?.levels[.volume]?.current == 10 && !model.isError
        }
        XCTAssertEqual(old.volumeWrites, [11])
        XCTAssertTrue(reopened.volumeWrites.isEmpty, "Recovery must never replay an old target")
        XCTAssertEqual(old.brightnessReads + reopened.brightnessReads, 1, "Healthy controls do not need another read")
        model.step(.volume, up: true)
        eventually("next input uses reopened service") { reopened.volumeWrites == [11] && !model.isError }
    }

    func testMissingVolumeAtStartupRetriesWhileBrightnessRemainsAvailable() {
        let device = FakeDevice()
        device.failVolumeReads(2)
        let source = FakeDiscovery([[device]])
        let model = model(source)
        defer { model.prepareForSleep() }
        model.scan()
        eventually("partial initial scan") { !model.scanning && model.selected != nil }
        XCTAssertNil(model.selected?.levels[.volume])
        XCTAssertNotNil(model.selected?.levels[.brightness])
        eventually("volume becomes readable without manual scan") { model.selected?.levels[.volume]?.current == 10 }
        XCTAssertEqual(source.calls, 3)
        XCTAssertEqual(device.brightnessReads, 1)
        XCTAssertTrue(device.volumeWrites.isEmpty)
    }

    func testWakeRetriesUntilSlowMonitorAppearsAndPreservesSelection() {
        let device = FakeDevice()
        let source = FakeDiscovery([[device], [], [], [device]])
        let model = model(source)
        defer { model.prepareForSleep() }
        model.scan()
        eventually("initial scan") { model.selected != nil }
        let selected = model.selectedID
        model.prepareForSleep()
        model.scan()
        runLoop(for: 0.15)
        XCTAssertEqual(source.calls, 1, "No DDC requests while asleep")
        XCTAssertEqual(model.selectedID, selected)
        model.resumeAfterSleep()
        eventually("late monitor recovers after wake") { source.calls == 4 && model.selected != nil }
        XCTAssertEqual(model.selectedID, selected)
        XCTAssertTrue(model.accepts(.adjust(.volume, true)))
    }

    func testActualDisconnectRemovesControlsAndReconnectDoesNotReplayVolume() {
        let old = FakeDevice(), reconnected = FakeDevice()
        let source = FakeDiscovery([[old], [], [reconnected]])
        let model = model(source, delays: [0.1])
        defer { model.prepareForSleep() }
        model.scan()
        eventually("initial scan") { model.selected != nil }
        old.failVolumeReads(1)
        model.step(.volume, up: true)
        eventually("disconnected device removed") { source.calls == 2 && model.displays.isEmpty }
        XCTAssertFalse(model.accepts(.adjust(.volume, true)))
        eventually("device reconnected automatically") { source.calls == 3 && model.selected != nil }
        XCTAssertEqual(model.selected?.levels[.volume]?.current, 10)
        XCTAssertTrue(reconnected.volumeWrites.isEmpty)
    }

    func testRecoveryReadCannotOverwriteNewerKeyboardInput() {
        let device = FakeDevice()
        let source = FakeDiscovery([[device]])
        let model = model(source, delays: [0.1])
        defer { model.prepareForSleep() }
        model.scan()
        eventually("initial scan") { model.selected != nil }
        device.failVolumeReads(1)
        model.step(.volume, up: true)
        eventually("failed readback") { model.isError }
        let started = expectation(description: "recovery read started")
        let release = DispatchSemaphore(value: 0)
        device.interceptNextVolumeRead {
            started.fulfill()
            _ = release.wait(timeout: .now() + 2)
            return Level(current: 9, maximum: 100)
        }
        wait(for: [started], timeout: 2)
        model.step(.volume, up: true)
        XCTAssertEqual(model.selected?.levels[.volume]?.current, 12)
        release.signal()
        runLoop(for: 0.03)
        XCTAssertEqual(model.selected?.levels[.volume]?.current, 12, "Old recovery result must not roll back pending input")
        eventually("new input verified") { device.volumeWrites == [11, 12] && !model.isError }
        XCTAssertEqual(model.selected?.levels[.volume]?.current, 12)
    }

    func testSleepDiscardsInflightRecoveryAndCancelsFurtherRetries() {
        let device = FakeDevice()
        device.failVolumeReads(1)
        let source = FakeDiscovery([[device]])
        let model = model(source, delays: [0.1])
        model.scan()
        eventually("partial initial scan") { model.selected != nil }
        let started = expectation(description: "recovery read started")
        let release = DispatchSemaphore(value: 0)
        device.interceptNextVolumeRead {
            started.fulfill()
            _ = release.wait(timeout: .now() + 2)
            return Level(current: 10, maximum: 100)
        }
        wait(for: [started], timeout: 2)
        model.prepareForSleep()
        release.signal()
        runLoop(for: 0.25)
        XCTAssertTrue(model.displays.isEmpty, "Late recovery must not resurrect sleeping devices")
        XCTAssertFalse(model.scanning)
        XCTAssertEqual(source.calls, 2)
        XCTAssertFalse(model.accepts(.adjust(.volume, true)))
    }

    func testRepeatedFailuresBackOffAndStopRetryingAfterSuccess() {
        let device = FakeDevice()
        device.failVolumeReads(5)
        let source = FakeDiscovery([[device]])
        let model = model(source)
        defer { model.prepareForSleep() }
        model.scan()
        eventually("persistent failure eventually recovers") { model.selected?.levels[.volume] != nil }
        XCTAssertEqual(source.calls, 6)
        let times = source.callTimes
        let minimumIntervals: [TimeInterval] = [0.03, 0.06, 0.1, 0.1, 0.1]
        if times.count == 6 {
            for index in minimumIntervals.indices {
                XCTAssertGreaterThanOrEqual(times[index + 1] - times[index], minimumIntervals[index] * 0.9)
            }
        }
        runLoop(for: 0.2)
        XCTAssertEqual(source.calls, 6, "Recovery stops once the control responds")
        XCTAssertTrue(device.volumeWrites.isEmpty)
    }
}
