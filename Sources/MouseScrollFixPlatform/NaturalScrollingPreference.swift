import Foundation

/// Reads the system Natural scrolling preference.
///
/// Apple exposes one shared preference for mouse and trackpad, which is exactly why a
/// "just invert the mouse" utility cannot work: the correct target depends on this
/// value. We only ever read it — never write it.
///
/// A missing key means the system default, which is natural scrolling ON. This was
/// confirmed on the development machine: `com.apple.swipescrolldirection` is absent
/// from the global domain until the user changes the setting.
public enum NaturalScrollingPreference {
    public static let key = "com.apple.swipescrolldirection"

    public static func isEnabled() -> Bool {
        guard let value = CFPreferencesCopyAppValue(
            key as CFString,
            kCFPreferencesAnyApplication
        ) else {
            return true
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let boolean = value as? Bool {
            return boolean
        }
        return true
    }
}
