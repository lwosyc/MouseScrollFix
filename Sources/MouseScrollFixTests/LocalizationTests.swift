import Foundation
import MouseScrollFixCore

enum LocalizationTests {
    static func run() {
        Harness.suite("Localization")

        Harness.test("both tables cover every key") {
            for key in TextKey.allCases {
                let english = Localization.english[key]
                let russian = Localization.russian[key]
                Harness.expect(
                    english?.isEmpty == false,
                    "missing English text for \(key.rawValue)"
                )
                Harness.expect(
                    russian?.isEmpty == false,
                    "missing Russian text for \(key.rawValue)"
                )
            }
        }

        Harness.test("no key falls back to its raw identifier") {
            for language in ResolvedLanguage.allCases {
                let localization = Localization(language: language)
                for key in TextKey.allCases {
                    Harness.expect(
                        localization.text(key) != key.rawValue,
                        "\(language.code) fell back to raw value for \(key.rawValue)"
                    )
                }
            }
        }

        Harness.test("russian table is actually translated") {
            let english = Localization(language: .english)
            let russian = Localization(language: .russian)
            // A sample of user-facing strings that must differ; brand names may not.
            let translatedKeys: [TextKey] = [
                .menuGrantPermission, .menuInvertVertical, .toggleInvertMouse,
                .statusActive, .statusPermissionRequired, .tabDiagnostics,
                .onboardingTitle, .onboardingButtonOpenSettings, .devicesTitle,
                .sectionCounters, .aboutPrivacyTitle, .valueOn
            ]
            for key in translatedKeys {
                Harness.expect(
                    english.text(key) != russian.text(key),
                    "\(key.rawValue) is identical in both languages"
                )
            }
        }

        Harness.test("system preference follows the OS language list") {
            Harness.expectEqual(
                Localization.resolve(preference: .system, preferredLanguages: ["ru-RU", "en-US"]).language,
                .russian
            )
            Harness.expectEqual(
                Localization.resolve(preference: .system, preferredLanguages: ["en-GB"]).language,
                .english
            )
            Harness.expectEqual(
                Localization.resolve(preference: .system, preferredLanguages: ["de-DE"]).language,
                .english,
                "unsupported languages fall back to English"
            )
            Harness.expectEqual(
                Localization.resolve(preference: .system, preferredLanguages: []).language,
                .english
            )
        }

        Harness.test("explicit preference overrides the OS language") {
            Harness.expectEqual(
                Localization.resolve(preference: .russian, preferredLanguages: ["en-US"]).language,
                .russian
            )
            Harness.expectEqual(
                Localization.resolve(preference: .english, preferredLanguages: ["ru-RU"]).language,
                .english
            )
        }

        Harness.test("placeholders are substituted in both languages") {
            for language in ResolvedLanguage.allCases {
                let localization = Localization(language: language)
                let rendered = localization.text(.menuMouseScrollingFormat, "X")
                Harness.expect(rendered.contains("X"), "\(language.code) did not substitute")
                Harness.expect(!rendered.contains("{0}"), "\(language.code) left a placeholder")

                let quit = localization.text(.menuQuit, "MouseScrollFix")
                Harness.expect(quit.contains("MouseScrollFix"), "quit string substitution")
            }
        }

        Harness.test("every format key has a placeholder") {
            let formatKeys: [TextKey] = [
                .menuStatusFormat, .menuMouseScrollingFormat, .menuTrackpadNaturalFormat,
                .menuDetectedFormat, .menuQuit, .tapSummaryFormat, .recordsFormat,
                .traceSavedFormat, .traceSaveFailedFormat, .launchAtLoginFailedFormat
            ]
            for key in formatKeys {
                for language in ResolvedLanguage.allCases {
                    let value = Localization(language: language).text(key)
                    Harness.expect(
                        value.contains("{0}"),
                        "\(key.rawValue) [\(language.code)] has no {{0}} placeholder"
                    )
                }
            }
        }
    }
}
