import CoreGraphics
import Foundation

/// One installed event tap, as reported by macOS.
public struct EventTapInfo: Sendable, Equatable {
    public let id: UInt32
    public let pid: Int32
    public let enabled: Bool
    public let isActiveFilter: Bool
    public let eventsOfInterest: UInt64
    public let averageUsecLatency: Float
    public let maximumUsecLatency: Float
}

/// Public diagnostics: what taps exist and how much latency they add.
///
/// `CGGetEventTapList` is the supported way to observe this, and it is the honest
/// answer to "is my tap actually running?" — permission preflight values lag, a live
/// tap does not.
public enum DiagnosticsService {
    public static func currentTaps() -> [EventTapInfo] {
        var count: UInt32 = 0
        guard CGGetEventTapList(0, nil, &count) == .success, count > 0 else { return [] }

        var list = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
        guard CGGetEventTapList(count, &list, &count) == .success else { return [] }

        return list.prefix(Int(count)).map { info in
            EventTapInfo(
                id: info.eventTapID,
                pid: info.tappingProcess,
                enabled: info.enabled,
                isActiveFilter: info.options == .defaultTap,
                eventsOfInterest: info.eventsOfInterest,
                averageUsecLatency: info.avgUsecLatency,
                maximumUsecLatency: info.maxUsecLatency
            )
        }
    }

    public static func hasActiveScrollTap(ownedBy pid: Int32) -> Bool {
        let scrollBit = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        return currentTaps().contains { tap in
            tap.pid == pid && tap.enabled && (tap.eventsOfInterest & scrollBit) != 0
        }
    }

    /// Writes an opt-in trace as JSON Lines, one record per line.
    public static func write(trace: [ScrollTraceRecord], to url: URL) throws {
        let text = trace.map(\.jsonLine).joined(separator: "\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
