import Foundation

/// Minimal dependency-free test harness.
///
/// XCTest is not shipped with the Command Line Tools, and this toolchain's
/// swift-testing integration produces an empty `__swift5_tests` discovery section,
/// so neither runner can be relied on. A self-contained runner keeps the suite
/// executable on any machine with a Swift toolchain — including this one:
///
///     swift run MouseScrollFixTests
///
/// Exits non-zero when any expectation fails, so it works in CI as well.
enum Harness {
    static var checks = 0
    static var failures: [String] = []
    static var currentTest = ""
    static var currentSuite = ""
    static var testsRun = 0

    static func banner(_ title: String) {
        print("\n\u{001B}[1m\(title)\u{001B}[0m")
    }

    static func suite(_ name: String) {
        currentSuite = name
        print("\n\(name)")
    }

    static func test(_ name: String, _ body: () -> Void) {
        currentTest = name
        testsRun += 1
        let failuresBefore = failures.count
        body()
        if failures.count == failuresBefore {
            print("  \u{001B}[32m✔\u{001B}[0m \(name)")
        } else {
            print("  \u{001B}[31m✘\u{001B}[0m \(name)")
        }
    }

    static func expect(
        _ condition: Bool,
        _ message: String = "expectation failed",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        checks += 1
        if !condition {
            failures.append("[\(currentSuite)] \(currentTest): \(message) — \(file):\(line)")
        }
    }

    static func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ label: String = "",
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        checks += 1
        if actual != expected {
            let prefix = label.isEmpty ? "" : "\(label): "
            failures.append(
                "[\(currentSuite)] \(currentTest): \(prefix)expected \(expected), got \(actual) — \(file):\(line)"
            )
        }
    }

    static func finish() -> Never {
        print("\n" + String(repeating: "─", count: 60))
        if failures.isEmpty {
            print("\u{001B}[32mAll \(testsRun) tests passed\u{001B}[0m (\(checks) expectations)")
            exit(0)
        }
        print("\u{001B}[31m\(failures.count) failure(s) in \(testsRun) tests\u{001B}[0m (\(checks) expectations)")
        for failure in failures {
            print("  • \(failure)")
        }
        exit(1)
    }
}
