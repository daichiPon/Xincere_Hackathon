import SwiftUI

/// S-08b やることのカレンダー表示。期限のあるタスクを月グリッドに置き、
/// 日を選ぶとその日のタスクを下に出す。期限なしのタスクは別枠でまとめる。
struct TaskCalendarView: View {
    @Environment(AppModel.self) private var model

    @State private var month: Date = Calendar.current.startOfDay(for: .now)
    @State private var selected: Date = Calendar.current.startOfDay(for: .now)

    private let cal = Calendar.current
    private let weekdaySymbols = ["日", "月", "火", "水", "木", "金", "土"]

    private var tasksByDay: [Date: [ProcedureTask]] {
        Dictionary(grouping: model.tasks.filter { $0.dueDate != nil }) {
            cal.startOfDay(for: $0.dueDate!)
        }
    }

    private var undatedTasks: [ProcedureTask] {
        model.tasks.filter { $0.dueDate == nil && $0.status != .done }
    }

    private var selectedTasks: [ProcedureTask] {
        (tasksByDay[cal.startOfDay(for: selected)] ?? [])
            .sorted { ($0.status == .done ? 1 : 0) < ($1.status == .done ? 1 : 0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            monthHeader
            weekdayHeader
            grid
            Divider()
            selectedDaySection
            if !undatedTasks.isEmpty { undatedSection }
        }
        .padding(16)
    }

    // MARK: - ヘッダ

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(month.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .foregroundStyle(Theme.brand)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { i, s in
                Text(s)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(i == 0 ? Theme.warn : (i == 6 ? Theme.brand : .secondary))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - グリッド

    private var grid: some View {
        let days = monthGridDays()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let inMonth = cal.isDate(day, equalTo: month, toGranularity: .month)
            let isSelected = cal.isDate(day, inSameDayAs: selected)
            let isToday = cal.isDateInToday(day)
            let count = tasksByDay[cal.startOfDay(for: day)]?.count ?? 0

            Button {
                selected = cal.startOfDay(for: day)
            } label: {
                VStack(spacing: 3) {
                    Text("\(cal.component(.day, from: day))")
                        .font(.subheadline)
                        .foregroundStyle(inMonth ? .primary : .tertiary)
                    Circle()
                        .fill(count > 0 ? Theme.warn : .clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Theme.brandSoft : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Theme.brand : .clear, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    // MARK: - 日別 / 期限なし

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selected.formatted(.dateTime.month().day().weekday(.short)))
                .font(.subheadline.weight(.semibold))
            if selectedTasks.isEmpty {
                Text("この日のやることはありません")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(selectedTasks) { task in
                    NavigationLink { TaskDetailView(taskID: task.id) } label: {
                        TaskCard(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var undatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("期限が未確定のやること")
                .font(.subheadline.weight(.semibold))
            ForEach(undatedTasks) { task in
                NavigationLink { TaskDetailView(taskID: task.id) } label: {
                    TaskCard(task: task)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - 日付計算

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) {
            month = cal.startOfDay(for: m)
        }
    }

    /// 月グリッド(日曜始まり)。前後の空きは nil。
    private func monthGridDays() -> [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: month),
              let firstWeekday = cal.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        let leading = firstWeekday - 1  // 日曜=1 起点
        let daysInMonth = cal.range(of: .day, in: .month, for: month)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<daysInMonth {
            cells.append(cal.date(byAdding: .day, value: offset, to: monthInterval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }
}

#Preview {
    NavigationStack {
        ScrollView { TaskCalendarView() }
            .environment(AppModel())
    }
}
