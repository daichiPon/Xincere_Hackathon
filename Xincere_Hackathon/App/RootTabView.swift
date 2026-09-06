import SwiftUI

/// §10.2 の情報アーキテクチャ。タブは 4 つ。
/// バッジは「やること」だけ。緊急時ガイドは「きく」タブに集約する。
/// 同じタブをもう一度タップすると、そのタブの画面スタックを先頭に戻す。
struct RootTabView: View {
    @Environment(AppModel.self) private var model

    enum Tab: Hashable { case today, growth, tasks, ask }

    @State private var selection: Tab = .today
    @State private var todayPath = NavigationPath()
    @State private var growthPath = NavigationPath()
    @State private var tasksPath = NavigationPath()
    @State private var askPath = NavigationPath()

    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == selection {
                    switch newValue {
                    case .today:  todayPath = NavigationPath()
                    case .growth: growthPath = NavigationPath()
                    case .tasks:  tasksPath = NavigationPath()
                    case .ask:    askPath = NavigationPath()
                    }
                }
                selection = newValue
            }
        )
    }

    var body: some View {
        ZStack {
            Theme.screenBackground.ignoresSafeArea()
            TabView(selection: tabSelection) {
                TodayView(navPath: $todayPath)
                    .tabItem { Label("今日", systemImage: "sun.max.fill") }
                    .tag(Tab.today)

                GrowthView(navPath: $growthPath)
                    .tabItem { Label("成長", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.growth)

                TasksView(navPath: $tasksPath)
                    .tabItem { Label("やること", systemImage: "checklist") }
                    .badge(model.actionableTaskCount)
                    .tag(Tab.tasks)

                AskView(navPath: $askPath)
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
        .environment(AuthStore())
}
