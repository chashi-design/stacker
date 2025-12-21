import SwiftUI
import UIKit

// アプリ全体のタブをまとめるエントリーポイント
struct ContentView: View {
    @State private var selectedTab: Tab = .summary

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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
        }
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
