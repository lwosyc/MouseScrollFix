import AppKit
import MouseScrollFixCore
import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: AppStatusModel
    @State private var saveMessage: String?

    var body: some View {
        Form {
            Section(model.text(.sectionRuntime)) {
                LabeledContent(model.text(.labelFilterState), value: model.statusHeadline)
                LabeledContent(
                    model.text(.labelAccessibility),
                    value: model.isAccessibilityTrusted ? model.text(.valueGranted) : model.text(.valueMissing)
                )
                LabeledContent(model.text(.labelNaturalScrolling), value: model.naturalScrollingDescription)
                LabeledContent(model.text(.labelEventTaps), value: model.tapsDescription)
            }

            Section(model.text(.sectionCounters)) {
                LabeledContent(model.text(.labelEventsSeen), value: "\(model.counters.eventsSeen)")
                LabeledContent(model.text(.labelInverted), value: "\(model.counters.inverted)")
                LabeledContent(model.text(.labelPassedThrough), value: "\(model.counters.passedThrough)")
                LabeledContent(model.text(.labelOwnSynthetic), value: "\(model.counters.ownSyntheticSkipped)")
                LabeledContent(model.text(.labelTapTimeout), value: "\(model.counters.tapDisabledByTimeout)")
                LabeledContent(model.text(.labelTapUserInput), value: "\(model.counters.tapDisabledByUserInput)")
                LabeledContent(model.text(.labelTapRecreated), value: "\(model.counters.tapRecreated)")
                LabeledContent(model.text(.labelClassifierResets), value: "\(model.counters.classifierResets)")
                HStack {
                    Button(model.text(.buttonResetCounters)) { model.resetCounters() }
                    Button(model.text(.buttonReinstallFilter)) { model.retryTap() }
                }
            }

            Section(model.text(.sectionTrace)) {
                Toggle(
                    model.text(.toggleRecordTrace),
                    isOn: Binding(
                        get: { model.settings.diagnosticsTrace },
                        set: { model.setDiagnosticsTrace($0) }
                    )
                )
                Text(model.text(.noteTrace))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button(model.text(.buttonSaveTrace)) { saveTrace() }
                        .disabled(model.traceCount == 0)
                    Button(model.text(.buttonClear)) { model.clearTrace() }
                        .disabled(model.traceCount == 0)
                    Spacer()
                    Text(model.text(.recordsFormat, String(model.traceCount)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let saveMessage {
                    Text(saveMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section(model.text(.sectionOtherTaps)) {
                if model.otherTaps.isEmpty {
                    Text(model.text(.otherTapsNone)).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.otherTaps.enumerated()), id: \.offset) { _, tap in
                        Text(
                            "pid \(tap.pid) · \(tap.enabled ? "on" : "off") · avg \(String(format: "%.1f", tap.averageUsecLatency)) µs"
                        )
                        .font(.caption)
                    }
                }
                Text(model.text(.otherTapsNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { model.refreshStatus() }
    }

    private func saveTrace() {
        let recordCount = model.traceCount
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mousescrollfix-trace.jsonl"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.saveTrace(to: url)
            saveMessage = model.text(
                .traceSavedFormat, String(recordCount), url.lastPathComponent
            )
        } catch {
            saveMessage = model.text(.traceSaveFailedFormat, error.localizedDescription)
        }
    }
}
