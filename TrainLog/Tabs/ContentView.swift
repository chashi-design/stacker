import SwiftUI

// アプリ全体のタブをまとめるエントリーポイント
struct ContentView: View {
    @State private var selectedTab: Tab = .summary
    @State private var tabHapticTrigger = 0
    @StateObject private var favoritesStore = ExerciseFavoritesStore()
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.kg.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewTabView()
                .tag(Tab.summary)
                .tabItem {
                    Label("アクティビティ", systemImage: "chart.bar.fill")
                }

            LogView()
                .tag(Tab.memo)
                .tabItem {
                    Label("メモ", systemImage: "calendar.badge.plus")
                }
            
            ExerciseTabView()
                .tag(Tab.exercises)
                .tabItem {
                    Label("種目", systemImage: "list.bullet")
                }
        }
        .onChange(of: selectedTab) { _, _ in
            tabHapticTrigger += 1
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tabHapticTrigger)
        .environmentObject(favoritesStore)
        .environment(\.weightUnit, WeightUnit(rawValue: weightUnitRaw) ?? .kg)
    }
}

private enum Tab {
    case summary
    case memo
    case exercises
}

#Preview {
    ContentView()
}
