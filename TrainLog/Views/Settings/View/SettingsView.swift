import SwiftUI

// 設定画面
struct SettingsView: View {
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    private var items: [SettingsLinkItem] {
        [
            SettingsLinkItem(
                title: strings.contactTitle,
                iconName: "questionmark.circle",
                url: URL(string: "https://forms.gle/zgHhoZLDLA7Y5Dmu6")!
            ),
            SettingsLinkItem(
                title: strings.termsTitle,
                iconName: "text.document",
                url: termsURL
            ),
            SettingsLinkItem(
                title: strings.privacyTitle,
                iconName: "lock",
                url: privacyPolicyURL
            )
        ]
    }

    @State private var selectedItem: SettingsLinkItem?
    @State private var isTutorialPresented = false
    @State private var navigationFeedbackTrigger = 0
    @State private var closeFeedbackTrigger = 0
    @State private var unitFeedbackTrigger = 0
    @Environment(\.dismiss) private var dismiss

    private var isJapaneseLocale: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private var strings: SettingsStrings {
        SettingsStrings(isJapanese: isJapaneseLocale)
    }

    private var docsBaseURL: String {
        "https://chashi-design.github.io/stacker"
    }

    private var localePath: String {
        isJapaneseLocale ? "ja" : "en"
    }

    private var termsURL: URL {
        URL(string: "\(docsBaseURL)/\(localePath)/terms")!
    }

    private var privacyPolicyURL: URL {
        URL(string: "\(docsBaseURL)/\(localePath)/privacypolicy")!
    }

    var body: some View {
        List {
            unitSection
            linksSection
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .listStyle(.insetGrouped)
        .navigationTitle(strings.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    closeFeedbackTrigger += 1
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.primary)
                }
                .accessibilityLabel(strings.closeLabel)
                .sensoryFeedback(.impact(weight: .light), trigger: closeFeedbackTrigger)
                .tint(.primary)
            }
        }
        .sheet(item: $selectedItem) { item in
            SafariView(url: item.url)
        }
        .fullScreenCover(isPresented: $isTutorialPresented) {
            TutorialView(isPresented: $isTutorialPresented)
        }
        .onChange(of: selectedItem) { _, newValue in
            if newValue != nil {
                navigationFeedbackTrigger += 1
            }
        }
        .onChange(of: isTutorialPresented) { _, newValue in
            if newValue {
                navigationFeedbackTrigger += 1
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: navigationFeedbackTrigger)
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        return version
    }

    private var unitSection: some View {
        Section(strings.appSettingsSectionTitle) {
            Picker(selection: $weightUnitRaw) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.unitLabel).tag(unit.rawValue)
                }
            }
            label: {
                HStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .foregroundStyle(.primary)
                        .font(.body)
                    Text(strings.weightUnitTitle)
                        .font(.body)
                }
            }
            .pickerStyle(.automatic)
            .onChange(of: weightUnitRaw) { _, _ in
                unitFeedbackTrigger += 1
            }
            .sensoryFeedback(.impact(weight: .light), trigger: unitFeedbackTrigger)
        }
    }

    private var linksSection: some View {
        Section(strings.otherSectionTitle) {
            Button {
                isTutorialPresented = true
            } label: {
                SettingsRow(title: strings.tutorialTitle, iconName: "sparkles")
            }
            .buttonStyle(.plain)

            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    SettingsRow(title: item.title, iconName: item.iconName)
                }
                .buttonStyle(.plain)
            }

            SettingsVersionRow(title: strings.versionTitle, versionText: appVersionText)
        }
    }
}

struct SettingsRow: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.primary)
                .font(.body)
            Text(title)
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsVersionRow: View {
    let title: String
    let versionText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundStyle(.primary)
                .font(.body)
            Text(title)
                .font(.body)
            Spacer()
            Text(versionText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct SettingsLinkItem: Identifiable, Hashable {
    let title: String
    let iconName: String
    let url: URL
    var id: URL { url }
}

private struct SettingsStrings {
    let isJapanese: Bool

    var navigationTitle: String { isJapanese ? "設定" : "Settings" }
    var closeLabel: String { isJapanese ? "閉じる" : "Close" }
    var appSettingsSectionTitle: String { isJapanese ? "アプリ設定" : "App Settings" }
    var weightUnitTitle: String { isJapanese ? "重量の単位" : "Weight Unit" }
    var otherSectionTitle: String { isJapanese ? "その他" : "Other" }
    var versionTitle: String { isJapanese ? "バージョン" : "Version" }
    var tutorialTitle: String { isJapanese ? "チュートリアル" : "Tutorial" }
    var contactTitle: String { isJapanese ? "お問い合わせ" : "Contact" }
    var termsTitle: String { isJapanese ? "利用規約" : "Terms of Service" }
    var privacyTitle: String { isJapanese ? "プライバシーポリシー" : "Privacy Policy" }
}
#Preview {
    NavigationStack {
        SettingsView()
    }
}
