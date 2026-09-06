import SwiftUI

/// §10.2 の情報アーキテクチャ。タブは 4 つ。
/// バッジは「やること」だけ。緊急時ガイドは「きく」タブに集約する。
/// 同じタブをもう一度タップすると、そのタブを作り直して先頭画面に戻す。
struct RootTabView: View {
    @Environment(AppModel.self) private var model

    enum Tab: Hashable { case today, growth, tasks, ask }

    @State private var selection: Tab = .today
    @State private var todayID = UUID()
    @State private var growthID = UUID()
    @State private var tasksID = UUID()
    @State private var askID = UUID()

    private var tabSelection: Binding<Tab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == selection {
                    switch newValue {
                    case .today:  todayID = UUID()
                    case .growth: growthID = UUID()
                    case .tasks:  tasksID = UUID()
                    case .ask:    askID = UUID()
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
                TodayView()
                    .id(todayID)
                    .tabItem { Label("今日", systemImage: "sun.max.fill") }
                    .tag(Tab.today)

                GrowthView()
                    .id(growthID)
                    .tabItem { Label("成長", systemImage: "chart.xyaxis.line") }
                    .tag(Tab.growth)

                TasksView()
                    .id(tasksID)
                    .tabItem { Label("やること", systemImage: "checklist") }
                    .badge(model.actionableTaskCount)
                    .tag(Tab.tasks)

                AskView()
                    .id(askID)
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
