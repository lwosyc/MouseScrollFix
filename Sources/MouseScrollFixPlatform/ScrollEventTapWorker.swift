import CoreGraphics
import Foundation
import MouseScrollFixCore

/// Owns the Quartz event tap for the whole process lifetime.
///
/// Design rules, all of them learned from how shipping utilities in this niche fail:
/// * The tap lives on its own `Thread` with its own `CFRunLoop`. A run loop only pumps
///   sources added to *its own* thread, so the tap source must be created and added
///   there — not on the main thread.
/// * All mutable stream state (`pipeline`) is touched only on that thread. No `CGEvent`
///   ever crosses a thread boundary.
/// * Nothing blocking happens inside the callback: no IPC, no logging, no allocation
///   loops. Only the shared counters/trace holder is touched, under a short lock.
/// * `kCGEventTapDisabledByTimeout` re-enables in place; `kCGEventTapDisabledByUserInput`
///   deliberately does *not* self-heal, so a user-requested off state stays off.
/// * A health check recreates the tap when the port goes invalid (standby, wake, load).
public final class ScrollEventTapWorker: @unchecked Sendable {
    public enum State: Equatable, Sendable {
        case stopped
        case running
        case pausedByUserInput
        case failed(String)

        public var isRunning: Bool { self == .running }
    }

    private enum Command: Hashable {
        case resetClassifier
        case recreate
        case stop
    }

    private let runtime: SharedRuntimeState
    private let lock = NSLock()

    private var thread: Thread?
    private var runLoop: CFRunLoop?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var commandSource: CFRunLoopSource?
    private var healthTimer: CFRunLoopTimer?
    private var pendingCommands: Set<Command> = []
    private var currentState: State = .stopped
    private var stateHandler: (@Sendable (State) -> Void)?

    /// Tap-thread-only state.
    private var pipeline = ScrollDecisionPipeline()

    private let healthInterval: CFTimeInterval = 5

    public init(runtime: SharedRuntimeState) {
        self.runtime = runtime
    }

    // MARK: Public API

    public var state: State {
        lock.lock()
        defer { lock.unlock() }
        return currentState
    }

    public func setStateHandler(_ handler: @escaping @Sendable (State) -> Void) {
        lock.lock()
        stateHandler = handler
        lock.unlock()
    }

    public func start() {
        lock.lock()
        if thread != nil {
            lock.unlock()
            return
        }
        let newThread = Thread { [self] in threadMain() }
        newThread.name = "MouseScrollFix scroll tap"
        newThread.qualityOfService = .userInteractive
        newThread.stackSize = 512 * 1024
        thread = newThread
        lock.unlock()
        newThread.start()
    }

    public func stop() {
        enqueue(.stop)
    }

    public func resetClassifier() {
        enqueue(.resetClassifier)
    }

    /// Recreates the tap. Pass a delay when the HID subsystem may still be settling —
    /// right after wake, for example.
    public func requestRecreate(delay: TimeInterval = 0) {
        guard delay > 0 else {
            enqueue(.recreate)
            return
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.enqueue(.recreate)
        }
    }

    // MARK: Thread plumbing

    private func threadMain() {
        if let source = makeCommandSource() {
            lock.lock()
            commandSource = source
            runLoop = CFRunLoopGetCurrent()
            lock.unlock()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        installHealthTimer()

        if createTap() {
            publish(.running)
        } else {
            publish(.failed(Self.permissionMessage))
        }

        CFRunLoopRun()

        tearDownTap()
        if let timer = takeHealthTimer() {
            CFRunLoopTimerInvalidate(timer)
        }
        lock.lock()
        runLoop = nil
        commandSource = nil
        thread = nil
        lock.unlock()
        publish(.stopped)
    }

    private static let permissionMessage =
        "The scroll event tap could not be created. Grant Accessibility permission, then retry."

    @discardableResult
    private func createTap() -> Bool {
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mouseScrollFixTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        lock.lock()
        tap = newTap
        tapSource = source
        lock.unlock()

        pipeline.reset()
        runtime.noteClassifierReset()

        if !CGEvent.tapIsEnabled(tap: newTap) {
            tearDownTap()
            return false
        }
        return true
    }

    private func tearDownTap() {
        lock.lock()
        let existingTap = tap
        let existingSource = tapSource
        tap = nil
        tapSource = nil
        lock.unlock()

        if let existingTap {
            CGEvent.tapEnable(tap: existingTap, enable: false)
            CFMachPortInvalidate(existingTap)
        }
        if let existingSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), existingSource, .commonModes)
        }

        pipeline.reset()
        runtime.noteClassifierReset()
    }

    private func recreateTap() {
        tearDownTap()
        runtime.noteTapRecreated()
        if createTap() {
            publish(.running)
        } else {
            publish(.failed(Self.permissionMessage))
        }
    }

    // MARK: Commands

    private func enqueue(_ command: Command) {
        lock.lock()
        pendingCommands.insert(command)
        let loop = runLoop
        let source = commandSource
        lock.unlock()

        guard let loop, let source else { return }
        CFRunLoopSourceSignal(source)
        CFRunLoopWakeUp(loop)
    }

    fileprivate func performCommands() {
        lock.lock()
        let commands = pendingCommands
        pendingCommands.removeAll()
        lock.unlock()

        if commands.contains(.resetClassifier) {
            pipeline.reset()
            runtime.noteClassifierReset()
        }
        if commands.contains(.recreate) {
            recreateTap()
        }
        if commands.contains(.stop) {
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }

    fileprivate func healthCheck() {
        lock.lock()
        let existingTap = tap
        let state = currentState
        lock.unlock()

        guard let existingTap else { return }

        if !CFMachPortIsValid(existingTap) {
            recreateTap()
            return
        }
        if state.isRunning, !CGEvent.tapIsEnabled(tap: existingTap) {
            CGEvent.tapEnable(tap: existingTap, enable: true)
            if !CGEvent.tapIsEnabled(tap: existingTap) {
                recreateTap()
            }
        }
    }

    // MARK: Event handling (tap thread)

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout:
            runtime.noteTapDisabledByTimeout()
            pipeline.reset()
            runtime.noteClassifierReset()
            lock.lock()
            let existingTap = tap
            lock.unlock()
            if let existingTap {
                CGEvent.tapEnable(tap: existingTap, enable: true)
                if !CGEvent.tapIsEnabled(tap: existingTap) {
                    enqueue(.recreate)
                }
            }
            publish(.running)
            return Unmanaged.passUnretained(event)

        case .tapDisabledByUserInput:
            runtime.noteTapDisabledByUserInput()
            pipeline.reset()
            runtime.noteClassifierReset()
            publish(.pausedByUserInput)
            return Unmanaged.passUnretained(event)

        case .scrollWheel:
            return rewrite(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func rewrite(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let fields = CGEventAccess.readFields(from: event)

        if SyntheticEventMarker.isOurs(fields.userData) {
            runtime.noteOwnSyntheticSkipped()
            return Unmanaged.passUnretained(event)
        }

        let result = pipeline.process(fields, context: runtime.currentPolicy())

        var reversed = false
        switch result.action {
        case .passThrough:
            runtime.noteEventPassedThrough()
        case .invert:
            let writes = ScrollMutationPlan.writes(
                for: fields,
                action: result.action,
                supportsExtendedFields: CGEventAccess.supportsExtendedFields
            )
            reversed = CGEventAccess.apply(writes, to: event)
            if reversed {
                runtime.noteEventInverted()
            } else {
                runtime.noteEventPassedThrough()
            }
        }

        runtime.appendTrace(
            ScrollTraceRecord(
                timestamp: fields.timestamp,
                streamClass: result.streamClass.rawValue,
                reason: result.reason.rawValue,
                action: reversed ? "inverted" : "passedThrough",
                isContinuous: fields.isContinuous,
                scrollPhase: fields.scrollPhase,
                momentumPhase: fields.momentumPhase,
                deltaAxis1: fields.deltaAxis1,
                pointDeltaAxis1: fields.pointDeltaAxis1,
                reversed: reversed
            )
        )

        return Unmanaged.passUnretained(event)
    }

    // MARK: Helpers

    private func makeCommandSource() -> CFRunLoopSource? {
        var context = CFRunLoopSourceContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil,
            equal: nil,
            hash: nil,
            schedule: nil,
            cancel: nil,
            perform: mouseScrollFixCommandPerform
        )
        return CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context)
    }

    private func installHealthTimer() {
        var context = CFRunLoopTimerContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        guard let timer = CFRunLoopTimerCreate(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + healthInterval,
            healthInterval,
            0,
            0,
            mouseScrollFixHealthPerform,
            &context
        ) else { return }
        CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, .commonModes)
        lock.lock()
        healthTimer = timer
        lock.unlock()
    }

    private func takeHealthTimer() -> CFRunLoopTimer? {
        lock.lock()
        defer { lock.unlock() }
        let timer = healthTimer
        healthTimer = nil
        return timer
    }

    private func publish(_ newState: State) {
        lock.lock()
        guard currentState != newState else {
            lock.unlock()
            return
        }
        currentState = newState
        let handler = stateHandler
        lock.unlock()

        if let handler {
            DispatchQueue.main.async { handler(newState) }
        }
    }
}

// MARK: - C callbacks

private let mouseScrollFixTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let worker = Unmanaged<ScrollEventTapWorker>.fromOpaque(userInfo).takeUnretainedValue()
    return worker.handle(type: type, event: event)
}

private let mouseScrollFixCommandPerform: @convention(c) (UnsafeMutableRawPointer?) -> Void = { info in
    guard let info else { return }
    Unmanaged<ScrollEventTapWorker>.fromOpaque(info).takeUnretainedValue().performCommands()
}

private let mouseScrollFixHealthPerform: CFRunLoopTimerCallBack = { _, info in
    guard let info else { return }
    Unmanaged<ScrollEventTapWorker>.fromOpaque(info).takeUnretainedValue().healthCheck()
}
