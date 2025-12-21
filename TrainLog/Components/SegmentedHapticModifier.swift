import SwiftUI

struct SegmentedHapticModifier<T: Equatable>: ViewModifier {
    let trigger: T

    func body(content: Content) -> some View {
        content.sensoryFeedback(.impact(weight: .light), trigger: trigger)
    }
}

extension View {
    func segmentedHaptic<T: Equatable>(trigger: T) -> some View {
        modifier(SegmentedHapticModifier(trigger: trigger))
    }
}
