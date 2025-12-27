import SwiftUI

// 設定画面
struct SettingsView: View {
    private let items: [SettingsLinkItem] = [
        SettingsLinkItem(
            title: "お問い合わせ",
            url: URL(string: "https://forms.gle/zgHhoZLDLA7Y5Dmu6")!
        ),
        SettingsLinkItem(
            title: "利用規約",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/termsofservice/japanese")!
        ),
        SettingsLinkItem(
            title: "プライバシーポリシー",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/privacypolicy/japanese")!
        ),
        SettingsLinkItem(
            title: "ライセンス",
            url: URL(string: "https://chashi-design.github.io/TrainLogApp/docs/license/licenseinfo")!
        )
    ]

    @State private var selectedItem: SettingsLinkItem?
    @State private var navigationFeedbackTrigger = 0
    @State private var closeFeedbackTrigger = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    SettingsRow(title: item.title)
                }
                .buttonStyle(.plain)
            }

            SettingsVersionRow(versionText: appVersionText)
        }
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
}

struct SettingsRow: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
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
            Text("バージョン")
            Spacer()
            Text(versionText)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsLinkItem: Identifiable, Hashable {
    let title: String
    let url: URL
    var id: URL { url }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
