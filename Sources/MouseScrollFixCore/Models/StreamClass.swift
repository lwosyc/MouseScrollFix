import Foundation

/// Classification of a scroll *stream* (not of a physical device).
///
/// macOS exposes no documented per-event device identity for scroll events, so the
/// unit of classification is the stream produced by one physical gesture or wheel
/// movement, inferred from `scrollPhase` / `momentumPhase` / `isContinuous`.
public enum StreamClass: String, Sendable, Equatable, CaseIterable {
    /// Built-in or external Apple trackpad. Evidence: `mayBegin`, or an established
    /// phased gesture window.
    case trackpad
    /// Phased touch surface that did not emit `mayBegin` (Magic Mouse, or a trackpad
    /// whose `mayBegin` was not delivered).
    case touchSurfaceOther
    /// Notched / line-based wheel (`isContinuous == 0`). Razer Orochi V2 and any
    /// ordinary USB, 2.4 GHz or Bluetooth wheel mouse land here.
    case wheelMouse
    /// Pixel-based, phase-free stream with no active touch gesture. High-resolution
    /// or free-spinning wheels, and mice whose vendor driver emits pixel deltas.
    case pixelMouse
    /// Posted by a user-space process (a driver helper, another utility, remote
    /// desktop) rather than originating in the HID stack.
    case injected
    /// Not enough evidence to classify.
    case unknown
}
