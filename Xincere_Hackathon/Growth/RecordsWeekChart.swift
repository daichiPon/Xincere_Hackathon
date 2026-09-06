import SwiftUI
import Charts

/// S-06b 1週間分の記録を「日 × 時刻」で見る。横軸=0〜24時、縦軸=日付。
/// 授乳・排泄などは点、睡眠は帯で表示。←→ で週を移動。
struct RecordsWeekChart: View {
    @Environment(AppModel.self) private var model

    /// 表示中の週の開始日(月曜)。
    @State private var weekStart: Date = RecordsWeekChart.mondayOfWeek(containing: .now)

    private let cal = Calendar.current

    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var weekEnd: Date { cal.date(byAdding: .day, value: 7, to: weekStart)! }

    private struct Event: Identifiable {
        let id: UUID
        let dayLabel: String
        let startHour: Double
        let endHour: Double?     // 睡眠のみ
        let kind: CareKind
    }

    private var events: [Event] {
        model.logs
            .filter { $0.time >= weekStart && $0.time < weekEnd }
            .map { log in
                let start = hourOfDay(log.time)
                var end: Double? = nil
                if log.kind == .sleep {
                    let mins = Double(Self.durationMinutes(log.detail))
                    if mins > 0 { end = min(24.0, start + mins / 60) }
                }
                return Event(id: log.id, dayLabel: dayLabel(log.time),
                             startHour: start, endHour: end, kind: log.kind)
            }
    }

    private var dayLabels: [String] { weekDays.map(dayLabel) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("記録のリズム").font(.headline)
                Spacer()
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                Text(rangeLabel).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(weekEnd > .now)
            }
            .foregroundStyle(Theme.brand)

            if events.isEmpty {
                Text("この週の記録はありません")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                chart
                legend
            }

            weekTotals
        }
        .cardStyle()
    }

    private var chart: some View {
        Chart {
            ForEach(events) { e in
                if let end = e.endHour {
                    BarMark(
                        xStart: .value("開始", e.startHour),
                        xEnd: .value("終了", end),
                        y: .value("日", e.dayLabel),
                        height: .fixed(8)
                    )
                    .foregroundStyle(by: .value("種類", e.kind.title))
                } else {
                    PointMark(
                        x: .value("時刻", e.startHour),
                        y: .value("日", e.dayLabel)
                    )
                    .symbolSize(50)
                    .foregroundStyle(by: .value("種類", e.kind.title))
                }
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartLegend(.hidden)
        .chartXScale(domain: 0.0...24.0)
        .chartYScale(domain: dayLabels)
        .chartXAxis {
            AxisMarks(values: [0.0, 6.0, 12.0, 18.0, 24.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let h = value.as(Double.self) { Text("\(Int(h))時") }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: dayLabels) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 220)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(legendKinds, id: \.self) { k in
                HStack(spacing: 4) {
                    Circle().fill(k.tint).frame(width: 8, height: 8)
                    Text(k.title).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var weekTotals: some View {
        let inWeek = model.logs.filter { $0.time >= weekStart && $0.time < weekEnd }
        func n(_ ks: [CareKind]) -> Int { inWeek.filter { ks.contains($0.kind) }.count }
        return Text("この週: 授乳・ミルク \(n([.feeding, .bottle]))回 ／ うんち \(n([.poop]))回 ／ おしっこ \(n([.pee, .diaper]))回 ／ 睡眠 \(n([.sleep]))回")
            .font(.caption2).foregroundStyle(.secondary)
    }

    // MARK: - スケール

    private var legendKinds: [CareKind] { [.feeding, .bottle, .sleep, .poop, .pee, .temperature] }

    private var colorScale: KeyValuePairs<String, Color> {
        [
            CareKind.feeding.title: CareKind.feeding.tint,
            CareKind.bottle.title: CareKind.bottle.tint,
            CareKind.sleep.title: CareKind.sleep.tint,
            CareKind.poop.title: CareKind.poop.tint,
            CareKind.pee.title: CareKind.pee.tint,
            CareKind.temperature.title: CareKind.temperature.tint,
        ]
    }

    // MARK: - Helpers

    private func hourOfDay(_ date: Date) -> Double {
        let c = cal.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d(E)"
        return f.string(from: date)
    }

    private var rangeLabel: String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        let last = cal.date(byAdding: .day, value: 6, to: weekStart)!
        return "\(f.string(from: weekStart))〜\(f.string(from: last))"
    }

    private func shiftWeek(_ delta: Int) {
        if let d = cal.date(byAdding: .day, value: delta * 7, to: weekStart) {
            weekStart = d
        }
    }

    private static func mondayOfWeek(containing date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 月曜
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }

    /// 「1時間40分」「45分」→ 分。
    static func durationMinutes(_ s: String) -> Int {
        let nums = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        if s.contains("時間") {
            let h = nums.first ?? 0
            let m = nums.count > 1 ? nums[1] : 0
            return h * 60 + m
        }
        return nums.first ?? 0
    }
}

#Preview {
    ScrollView { RecordsWeekChart().environment(AppModel()) }
}
