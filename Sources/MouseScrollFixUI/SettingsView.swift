import AppKit
import MouseScrollFixCore
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var model: AppStatusModel

    public init(model: AppStatusModel) {
        self.model = model
    }

    public var body: some View {
        TabView(selection: $model.selectedTab) {
            GeneralSettingsView(model: model)
                .tabItem {
                    Label(
                        SettingsTab.general.title(model.localization),
                        systemImage: SettingsTab.general.iconName()
                    )
                }
                .tag(SettingsTab.general)

            DevicesView(model: model)
                .tabItem {
                    Label(
                        SettingsTab.devices.title(model.localization),
                        systemImage: SettingsTab.devices.iconName()
                    )
                }
                .tag(SettingsTab.devices)

            DiagnosticsView(model: model)
                .tabItem {
                    Label(
                        SettingsTab.diagnostics.title(model.localization),
                        systemImage: SettingsTab.diagnostics.iconName()
                    )
                }
                .tag(SettingsTab.diagnostics)

            AboutView(model: model)
                .tabItem {
                    Label(
                        SettingsTab.about.title(model.localization),
                        systemImage: SettingsTab.about.iconName()
                    )
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 600, height: 500)
        .padding(12)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var model: AppStatusModel

    var body: some View {
        Form {
            Section {
                StatusBadge(model: model)
            }

            Section(model.text(.sectionMouseScrolling)) {
                Toggle(
                    model.text(.toggleInvertMouse),
                    isOn: Binding(
                        get: { model.settings.mouseInversionEnabled },
                        set: { model.setEnabled($0) }
                    )
                )
                Toggle(
                    model.text(.toggleInvertVertical),
                    isOn: Binding(
                        get: { model.settings.invertVertical },
                        set: { model.setInvertVertical($0) }
                    )
                )
                .disabled(!model.settings.mouseInversionEnabled)

                Toggle(
                    model.text(.toggleInvertHorizontal),
                    isOn: Binding(
                        get: { model.settings.invertHorizontal },
                        set: { model.setInvertHorizontal($0) }
                    )
                )
                .disabled(!model.settings.mouseInversionEnabled)
            }

            Section(model.text(.sectionDeviceHandling)) {
                Toggle(
                    model.text(.toggleAutomaticDetection),
                    isOn: Binding(
                        get: { model.settings.automaticMouseDetection },
                        set: { model.setAutomaticMouseDetection($0) }
                    )
                )

                Picker(
                    model.text(.pickerAmbiguousPixel),
                    selection: Binding(
                        get: { model.settings.ambiguousPixelPolicy },
                        set: { model.setAmbiguousPixelPolicy($0) }
                    )
                ) {
                    Text(model.text(.optTreatAsMouse)).tag(AmbiguousPixelPolicy.treatAsMouse)
                    Text(model.text(.optPassThrough)).tag(AmbiguousPixelPolicy.passThrough)
                }

                Picker(
                    model.text(.pickerTouchSurface),
                    selection: Binding(
                        get: { model.settings.touchSurfaceWithoutMayBegin },
                        set: { model.setTouchSurfacePolicy($0) }
                    )
                ) {
                    Text(model.text(.optKeepNatural)).tag(TouchSurfacePolicy.keepNatural)
                    Text(model.text(.optInvertAsMouse)).tag(TouchSurfacePolicy.invert)
                }

                Picker(
                    model.text(.pickerInjectedEvents),
                    selection: Binding(
                        get: { model.settings.injectedEventsPolicy },
                        set: { model.setInjectedEventsPolicy($0) }
                    )
                ) {
                    Text(model.text(.optTreatAsMouse)).tag(InjectedEventsPolicy.treatAsMouse)
                    Text(model.text(.optPassThrough)).tag(InjectedEventsPolicy.passThrough)
                }
            }

            Section(model.text(.sectionSystem)) {
                LabeledContent(model.text(.labelNaturalScrolling), value: model.naturalScrollingDescription)

                Picker(
                    model.text(.pickerLanguage),
                    selection: Binding(
                        get: { model.settings.language },
                        set: { model.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }

                Toggle(
                    model.text(.toggleLaunchAtLogin),
                    isOn: Binding(
                        get: { model.settings.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                Text(model.text(.noteLaunchAtLogin))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !model.launchAtLoginStatus.isEmpty {
                    Text(model.launchAtLoginStatus)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// The coloured status line shared by the settings window and the onboarding window.
struct StatusBadge: View {
    @ObservedObject var model: AppStatusModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.statusHeadline).font(.headline)
                Text(model.statusDetail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var color: Color {
        if !model.settings.mouseInversionEnabled { return .secondary }
        return model.isActive ? .green : .orange
    }
}

struct AboutView: View {
    @ObservedObject var model: AppStatusModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.text(.appName)).font(.title2).bold()
                    Text(model.text(.aboutTagline)).foregroundStyle(.secondary)
                }
            }

            Divider()

            Text(model.text(.aboutHowItWorksTitle)).font(.headline)
            Text(model.text(.aboutHowItWorksBody)).font(.callout)

            Divider()

            Text(model.text(.aboutPrivacyTitle)).font(.headline)
            Text(model.text(.aboutPrivacyBody)).font(.callout)

            Spacer()
        }
        .padding()
    }
}
