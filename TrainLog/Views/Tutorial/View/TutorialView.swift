import SwiftUI
import UIKit

// 初回チュートリアル画面
struct TutorialView: View {
    @Binding var isPresented: Bool
    let enableFadeIn: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentIndex = 0
    @State private var swipeFeedbackTrigger = 0
    @State private var isManualAdvance = false
    @State private var isContentVisible = false
    private let landscapeTextMaxWidth: CGFloat = 320

    init(isPresented: Binding<Bool>, enableFadeIn: Bool = false) {
        _isPresented = isPresented
        self.enableFadeIn = enableFadeIn
    }

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var pages: [TutorialPage] {
        if isJapaneseLocale {
            return [
                TutorialPage(
                    title: "Biggr へようこそ",
                    message: "基本的な使い方を簡単にご紹介します。",
                    imageName: "Tutorial1"
                ),
                TutorialPage(
                    title: "サクッと記録",
                    message: "カレンダーから日付を選んで記録するだけ。\n「いつ・どんなトレーニングをしたか」をすぐに振り返れます。",
                    imageName: "Tutorial2"
                ),
                TutorialPage(
                    title: "記録を振り返る",
                    message: "日々の記録をもとに、トレーニング種目の割合や総ボリュームの変化などまとめて確認できます。",
                    imageName: "Tutorial3"
                ),
                TutorialPage(
                    title: "記録をもっとスムーズに",
                    message: "よく行う種目を登録しておけば、記録のたびにすぐ見つかります。",
                    imageName: "Tutorial4"
                )
            ]
        }

        return [
            TutorialPage(
                title: "Welcome to Biggr",
                message: "A quick overview of the basics.",
                imageName: "Tutorial1"
            ),
            TutorialPage(
                title: "Log in a snap",
                message: "Just pick a date on the calendar and log it.\nReview when and what you trained at a glance.",
                imageName: "Tutorial2"
            ),
            TutorialPage(
                title: "Review your logs",
                message: "Check exercise share and total volume trends from your daily records.",
                imageName: "Tutorial3"
            ),
            TutorialPage(
                title: "Make logging smoother",
                message: "Save frequent exercises so you can find them quickly when logging.",
                imageName: "Tutorial4"
            )
        ]
    }

    private var strings: TutorialStrings {
        TutorialStrings(isJapanese: isJapaneseLocale)
    }

    private var controls: some View {
        VStack(spacing: 24) {
            PageIndicatorView(pageCount: pages.count, currentIndex: currentIndex)
                .padding(.horizontal, 24)

            HapticButton {
                handlePrimaryAction()
            } label: {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let contentWidth = max(proxy.size.width - 32, 0)
            let rightColumnWidth = min(landscapeTextMaxWidth, contentWidth * 0.45)
            let leftColumnWidth = max(contentWidth - rightColumnWidth - 24, 0)
            let imageMaxWidth = min(isLandscape ? leftColumnWidth : proxy.size.width, 500)
            let bottomPadding: CGFloat = 0
            if isLandscape {
                HStack(alignment: .top, spacing: 24) {
                    TabView(selection: $currentIndex) {
                        ForEach(pages.indices, id: \.self) { index in
                            TutorialPageImageView(imageName: resolvedImageName(for: pages[index].imageName),
                                                  maxWidth: imageMaxWidth)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    VStack(spacing: 24) {
                        TutorialPageTextView(page: pages[currentIndex])
                        Spacer(minLength: 0)
                        controls
                    }
                    .frame(width: rightColumnWidth, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            } else {
                VStack(spacing: 0) {
                    TabView(selection: $currentIndex) {
                        ForEach(pages.indices, id: \.self) { index in
                            TutorialPageView(page: pages[index],
                                             imageMaxWidth: imageMaxWidth,
                                             imageNameResolver: resolvedImageName)
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .bottom) {
                    controls
                        .padding(.bottom, bottomPadding)
                }
            }
        }
        .opacity(enableFadeIn ? (isContentVisible ? 1 : 0) : 1)
        .onAppear {
            if enableFadeIn {
                withAnimation(.easeOut(duration: 0.35)) {
                    isContentVisible = true
                }
            } else {
                isContentVisible = true
            }
        }
        .interactiveDismissDisabled(currentIndex < pages.count - 1)
        .onChange(of: currentIndex) { _, _ in
            if isManualAdvance {
                isManualAdvance = false
            } else {
                swipeFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: swipeFeedbackTrigger)
    }

    private var primaryButtonTitle: String {
        currentIndex == pages.count - 1 ? strings.startButtonTitle : strings.nextButtonTitle
    }

    private func resolvedImageName(for baseName: String) -> String {
        let localeSuffix = isJapaneseLocale ? "ja" : "en"
        let schemeSuffix = colorScheme == .dark ? "dark" : "light"
        let variantName = "\(baseName)_\(localeSuffix)_\(schemeSuffix)"
        var candidates: [String] = []
        if let index = tutorialIndex(from: baseName) {
            candidates.append("Tutorial/\(index)/\(variantName)")
            candidates.append("Tutorial/\(index)/\(baseName)")
        }
        candidates.append("Tutorial/\(variantName)")
        candidates.append(variantName)
        candidates.append("Tutorial/\(baseName)")
        candidates.append(baseName)

        for name in candidates {
            if UIImage(named: name) != nil {
                return name
            }
        }
        return baseName
    }

    private func tutorialIndex(from baseName: String) -> String? {
        let digits = baseName.reversed().prefix { $0.isNumber }.reversed()
        guard !digits.isEmpty else { return nil }
        return String(digits)
    }

    private func handlePrimaryAction() {
        if currentIndex < pages.count - 1 {
            withAnimation(.easeInOut) {
                isManualAdvance = true
                currentIndex += 1
            }
        } else {
            isPresented = false
        }
    }
}

private struct TutorialPage {
    let title: String
    let message: String
    let imageName: String
}

private struct TutorialPageView: View {
    let page: TutorialPage
    let imageMaxWidth: CGFloat
    let imageNameResolver: (String) -> String
    private let textBlockMinHeight: CGFloat = 88

    var body: some View {
        VStack(spacing: 32) {
            TutorialPageImageView(imageName: imageNameResolver(page.imageName), maxWidth: imageMaxWidth)
            TutorialPageTextView(page: page)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 0)
        .padding(.horizontal, 0)
    }
}

private struct TutorialPageImageView: View {
    let imageName: String
    let maxWidth: CGFloat

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: maxWidth)
    }
}

private struct TutorialPageTextView: View {
    let page: TutorialPage
    private let textBlockMinHeight: CGFloat = 88

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text(page.message)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .frame(minHeight: textBlockMinHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
}

private struct PageIndicatorView: View {
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(currentIndex + 1) / \(pageCount)")
    }
}

private struct TutorialStrings {
    let isJapanese: Bool

    var title: String { isJapanese ? "チュートリアル" : "Tutorial" }
    var nextButtonTitle: String { isJapanese ? "次へ" : "Next" }
    var startButtonTitle: String { isJapanese ? "始める" : "Get Started" }
}

#Preview {
    TutorialView(isPresented: .constant(true))
}
