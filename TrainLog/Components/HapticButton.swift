import SwiftUI

struct HapticButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var trigger: Int = 0

    var body: some View {
        Button {
            trigger += 1
            action()
        } label: {
            label()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: trigger)
    }
}
