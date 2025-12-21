import SwiftUI

// アプリ全体のタブをまとめるエントリーポイント
struct ContentView: View {
    var body: some View {
        TabView {
            OverviewTabView()
                .tabItem {
                    Label("サマリー", systemImage: "chart.bar.fill")
                }


            LogView()
                .tabItem {
                    Label("メモ", systemImage: "calendar.badge.plus")
                }
            
            ExerciseTabView()
                .tabItem {
                    Label("種目", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    ContentView()
}
