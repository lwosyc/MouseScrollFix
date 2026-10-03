import AppKit
import MouseScrollFixCore
import SwiftUI

/// The window shown on first launch, and whenever the app is missing its permission.
///
/// Written to answer "what is this prompt and why" without jargon: what access is
/// needed, what the app does not do with it, the exact click path, and a button that
/// re-checks the permission state.
public struct OnboardingView: View {
    @ObservedObject private var model: AppStatusModel
    private let onDismiss: () -> Void

    public init(model: AppStatusModel, onDismiss: @escaping () -> Void) {
        self.model = model
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if model.isAccessibilityTrusted {
                grantedSection
            } else {
                explanation
                steps
            }

            Divider()
            footer
        }
        .padding(24)
        .frame(width: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.isAccessibilityTrusted ? model.text(.onboardingGrantedTitle) : model.text(.onboardingTitle))
                    .font(.title2)
                    .bold()
                if model.isAccessibilityTrusted {
                    Text(model.text(.onboardingGrantedBody))
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.text(.onboardingIntro))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.text(.onboardingWhyTitle)).font(.headline)
            Text(model.text(.onboardingWhyBody)).font(.callout)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.text(.onboardingStepsTitle)).font(.headline)
            Group {
                Text(model.text(.onboardingStep1))
                Text(model.text(.onboardingStep2))
                Text(model.text(.onboardingStep3))
                Text(model.text(.onboardingStep4))
            }
            .font(.callout)

            Text(model.text(.onboardingNotePath))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var grantedSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title2)
            StatusBadge(model: model)
        }
    }

    private var footer: some View {
        HStack {
            if !model.isAccessibilityTrusted {
                Button(model.text(.onboardingButtonLater)) { onDismiss() }
            }
            Spacer()
            if model.isAccessibilityTrusted {
                Button(model.text(.onboardingButtonDone)) { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(model.text(.onboardingButtonCheckAgain)) {
                    model.refreshSystemState()
                }
                Button(model.text(.onboardingButtonOpenSettings)) {
                    model.openAccessibilitySettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(model.text(.onboardingReopenHint))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .offset(y: 18)
        }
    }
}
