import Foundation

/// Cancels superseded commands waiting on the serial hardware queue.
public final class WriteTicket: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    public init() {}
    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }
    public func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
    }
}
