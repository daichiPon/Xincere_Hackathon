import SwiftUI

/// §10.2 の情報アーキテクチャ。タブは 4 つまで。
/// バッジは「やること」だけに付ける。緊急時ボタンは各画面のヘッダに常設する。
struct RootTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: Tab = .today

    enum Tab: Hashable {
        case today, growth, tasks, ask
    }

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()
            TabView(selection: $selection) {
                TodayView()
                    .tabItem { Label("今日", systemImage: "sun.max.fill") }
                    .tag(Tab.today)

                GrowthView()
                    .tabItem { Label("成長", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.growth)

                TasksView()
                    .tabItem { Label("やること", systemImage: "checklist") }
                    .badge(model.actionableTaskCount)
                    .tag(Tab.tasks)

                AskView()
                    .tabItem { Label("きく", systemImage: "bubble.left.and.text.bubble.right.fill") }
                    .tag(Tab.ask)
            }
            .tint(Theme.brand)
            .toolbarBackground(Theme.screenBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppModel())
}
