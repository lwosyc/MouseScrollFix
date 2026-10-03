import Foundation
import MouseScrollFixCore

/// One entry of the opt-in diagnostic trace.
public struct ScrollTraceRecord: Sendable, Equatable {
    public let timestamp: UInt64
    public let streamClass: String
    public let reason: String
    public let action: String
    public let isContinuous: Bool
    public let scrollPhase: Int64
    public let momentumPhase: Int64
    public let deltaAxis1: Int64
    public let pointDeltaAxis1: Int64
    public let reversed: Bool

    public var jsonLine: String {
        let dict: [String: Any] = [
            "timestamp": timestamp,
            "class": streamClass,
            "reason": reason,
            "action": action,
            "isContinuous": isContinuous,
            "scrollPhase": scrollPhase,
            "momentumPhase": momentumPhase,
            "deltaAxis1": deltaAxis1,
            "pointDeltaAxis1": pointDeltaAxis1,
            "reversed": reversed
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

/// Counters shown by the diagnostics pane and used as a health signal.
public struct ScrollCounters: Sendable, Equatable {
    public var eventsSeen = 0
    public var inverted = 0
    public var passedThrough = 0
    public var ownSyntheticSkipped = 0
    public var tapDisabledByTimeout = 0
    public var tapDisabledByUserInput = 0
    public var tapRecreated = 0
    public var classifierResets = 0

    public init() {}
}

/// Runtime state shared between the event-tap thread and the main actor.
///
/// The tap thread reads the policy on every scroll event, so the holder has to be
/// cheap and lock-based rather than an actor. Scroll events arrive at most a few
/// hundred times per second; an uncontended `NSLock` is far below the budget.
public final class SharedRuntimeState: @unchecked Sendable {
    private let lock = NSLock()

    private var policy = PolicyContext.default
    private var counters = ScrollCounters()
    private var traceEnabled = false
    private var trace: [ScrollTraceRecord] = []
    private let traceLimit = 4096

    public init() {}

    // MARK: Policy

    public func updatePolicy(_ newValue: PolicyContext) {
        lock.lock()
        policy = newValue
        lock.unlock()
    }

    public func currentPolicy() -> PolicyContext {
        lock.lock()
        defer { lock.unlock() }
        return policy
    }

    // MARK: Counters

    public func snapshotCounters() -> ScrollCounters {
        lock.lock()
        defer { lock.unlock() }
        return counters
    }

    public func resetCounters() {
        lock.lock()
        counters = ScrollCounters()
        lock.unlock()
    }

    public func noteEventInverted() {
        lock.lock(); counters.eventsSeen += 1; counters.inverted += 1; lock.unlock()
    }

    public func noteEventPassedThrough() {
        lock.lock(); counters.eventsSeen += 1; counters.passedThrough += 1; lock.unlock()
    }

    public func noteOwnSyntheticSkipped() {
        lock.lock(); counters.eventsSeen += 1; counters.ownSyntheticSkipped += 1; lock.unlock()
    }

    public func noteTapDisabledByTimeout() {
        lock.lock(); counters.tapDisabledByTimeout += 1; lock.unlock()
    }

    public func noteTapDisabledByUserInput() {
        lock.lock(); counters.tapDisabledByUserInput += 1; lock.unlock()
    }

    public func noteTapRecreated() {
        lock.lock(); counters.tapRecreated += 1; lock.unlock()
    }

    public func noteClassifierReset() {
        lock.lock(); counters.classifierResets += 1; lock.unlock()
    }

    // MARK: Trace

    public var isTraceEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return traceEnabled
    }

    public func setTraceEnabled(_ enabled: Bool) {
        lock.lock()
        traceEnabled = enabled
        if !enabled { trace.removeAll(keepingCapacity: true) }
        lock.unlock()
    }

    public func appendTrace(_ record: ScrollTraceRecord) {
        lock.lock()
        if traceEnabled {
            trace.append(record)
            if trace.count > traceLimit {
                trace.removeFirst(trace.count - traceLimit)
            }
        }
        lock.unlock()
    }

    public func snapshotTrace() -> [ScrollTraceRecord] {
        lock.lock()
        defer { lock.unlock() }
        return trace
    }

    public func clearTrace() {
        lock.lock()
        trace.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
