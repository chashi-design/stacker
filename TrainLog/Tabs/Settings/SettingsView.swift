import SwiftUI

// 設定画面
struct SettingsView: View {
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue
    private let items: [SettingsLinkItem] = [
        SettingsLinkItem(
            title: "お問い合わせ",
            iconName: "questionmark.circle",
            url: URL(string: "https://forms.gle/zgHhoZLDLA7Y5Dmu6")!
        ),
        SettingsLinkItem(
            title: "利用規約",
            iconName: "text.document",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/termsofservice/japanese")!
        ),
        SettingsLinkItem(
            title: "プライバシーポリシー",
            iconName: "lock",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/privacypolicy/japanese")!
        ),
        SettingsLinkItem(
            title: "ライセンス",
            iconName: "medal.star",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/license/licenseinfo")!
        )
    ]

    @State private var selectedItem: SettingsLinkItem?
    @State private var navigationFeedbackTrigger = 0
    @State private var closeFeedbackTrigger = 0
    @State private var unitFeedbackTrigger = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            unitSection
            linksSection
        }
        .contentMargins(.top, 4, for: .scrollContent)
        .listStyle(.insetGrouped)
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    closeFeedbackTrigger += 1
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("閉じる")
                .sensoryFeedback(.impact(weight: .light), trigger: closeFeedbackTrigger)
            }
        }
        .sheet(item: $selectedItem) { item in
            SafariView(url: item.url)
        }
        .onChange(of: selectedItem) { _, newValue in
            if newValue != nil {
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
        Section("アプリ設定") {
            Picker(selection: $weightUnitRaw) {
                ForEach(WeightUnit.allCases) { unit in
                    Text(unit.unitLabel).tag(unit.rawValue)
                }
            }
            label: {
                HStack {
                    Image(systemName: "dumbbell")
                        .foregroundStyle(.primary)
                        .font(.headline.weight(.semibold))
                    Text("重量の単位")
                        .font(.headline)
                }
            }
            .pickerStyle(.automatic)
            .fontWeight(.semibold)
            .onChange(of: weightUnitRaw) { _, _ in
                unitFeedbackTrigger += 1
            }
            .sensoryFeedback(.impact(weight: .light), trigger: unitFeedbackTrigger)
        }
    }

    private var linksSection: some View {
        Section("その他") {
            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    SettingsRow(title: item.title, iconName: item.iconName)
                }
                .buttonStyle(.plain)
            }

            SettingsVersionRow(versionText: appVersionText)
        }
    }
}

struct SettingsRow: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(.primary)
                .font(.headline.weight(.semibold))
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct SettingsVersionRow: View {
    let versionText: String

    var body: some View {
        HStack {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundStyle(.primary)
                .font(.headline.weight(.semibold))
            Text("バージョン")
                .font(.headline)
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

#Preview {
    NavigationStack {
        SettingsView()
    }
}
