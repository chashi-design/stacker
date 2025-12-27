// ログ画面向けView拡張
// キーボードを確実に閉じるため、UIKit の resignFirstResponder を利用
import SwiftUI
import UIKit

struct SearchToolbarVisibility: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    @ViewBuilder
    func applyScrollEdgeEffectStyleIfAvailable() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}
