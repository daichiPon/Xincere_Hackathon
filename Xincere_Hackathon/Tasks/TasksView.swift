import SwiftUI

/// S-08 やること一覧。§10.3 ③やること に従う縦タイムライン。
/// カードは 3 種類のみ: 期限あり(赤系) / 予定(通常) / 完了(グレーアウト)。
struct TasksView: View {
    @Environment(AppModel.self) private var model

    private var sortedTasks: [ProcedureTask] {
        model.tasks.sorted { a, b in
            // 完了は末尾、それ以外は期限が近い順。
            if (a.status == .done) != (b.status == .done) { return a.status != .done }
            return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
        }
    }

    private var programsLink: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title3)
                .foregroundStyle(Theme.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(TokyoWard.normalized(model.municipality))の子育て支援制度")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("給付金・助成・保活の締切を見る")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    NavigationLink {
                        ProgramsView()
                    } label: {
                        programsLink
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)

                    ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                        TimelineRow(task: task, isLast: index == sortedTasks.count - 1)
                    }
                }
                .padding(16)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("やること")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { EmergencyButton() }
            }
        }
    }
}

/// タイムラインの 1 行（左に軸、右にカード）。
private struct TimelineRow: View {
    @Environment(AppModel.self) private var model
    let task: ProcedureTask
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 縦軸のドットとライン
            VStack(spacing: 0) {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
                    .padding(.top, 20)
                if !isLast {
                    Rectangle()
                        .fill(Theme.separator)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            NavigationLink {
                TaskDetailView(taskID: task.id)
            } label: {
                TaskCard(task: task)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
    }

    private var accent: Color {
        switch task.status {
        case .dueSoon: Theme.warn
        case .scheduled: Theme.brand
        case .done: Theme.separator
        }
    }
}

struct TaskCard: View {
    let task: ProcedureTask

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(task.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(accent.opacity(0.16), in: Capsule())
                Spacer()
                dueLabel
            }

            Text(task.title)
                .font(.headline)
                .foregroundStyle(task.status == .done ? .secondary : .primary)
                .strikethrough(task.status == .done)

            HStack(spacing: 6) {
                Image(systemName: task.assignee.symbol)
                    .foregroundStyle(task.assignee == .unassigned ? Theme.warn : Theme.brand)
                if task.assignee == .unassigned {
                    Text("担当を決める")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.warn)
                } else {
                    Text(task.assignee.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .stroke(task.status == .dueSoon ? Theme.warn.opacity(0.5) : .clear, lineWidth: 1.5)
        )
        .opacity(task.status == .done ? 0.6 : 1)
    }

    private var accent: Color {
        switch task.status {
        case .dueSoon: Theme.warn
        case .scheduled: Theme.brand
        case .done: Color.secondary
        }
    }

    @ViewBuilder
    private var dueLabel: some View {
        switch task.status {
        case .done:
            Label("完了", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        case .dueSoon, .scheduled:
            if let due = task.dueDate {
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: due)).day ?? 0
                Text(days <= 0 ? "本日まで" : "あと\(days)日")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(task.status == .dueSoon ? Theme.warn : .secondary)
            }
        }
    }
}

#Preview {
    TasksView()
        .environment(AppModel())
}
