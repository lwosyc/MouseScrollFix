import Foundation

/// Composes classification and policy into one decision. The event-tap worker uses
/// this and nothing else, so the entire behavioural contract is exercised by unit
/// tests without touching CoreGraphics.
public struct ScrollDecisionPipeline: Sendable {
    public private(set) var classifier: ScrollStreamClassifier

    public init(timing: TimingConstants = .default) {
        self.classifier = ScrollStreamClassifier(timing: timing)
    }

    public mutating func reset() {
        classifier.reset()
    }

    public struct Result: Sendable, Equatable {
        public let streamClass: StreamClass
        public let reason: ClassifierReason
        public let action: ScrollAction
        public let wouldInvert: Bool
    }

    public mutating func process(
        _ fields: ScrollFields,
        context: PolicyContext
    ) -> Result {
        let decision = classifier.classify(fields)
        let action = ScrollPolicyEngine.action(for: decision.streamClass, context: context)
        return Result(
            streamClass: decision.streamClass,
            reason: decision.reason,
            action: action,
            wouldInvert: !action.isPassThrough
        )
    }
}
