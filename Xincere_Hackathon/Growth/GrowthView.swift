import SwiftUI
import Charts

/// S-06 成長ダッシュボード。§10.3 ②成長 / §4.3.3 の表示要件に従う。
/// 帯の中に点を置く。評価語を使わない。修正/暦月齢トグルを常時明示。
struct GrowthView: View {
    @Environment(AppModel.self) private var model
    @Binding var navPath: NavigationPath
    @State private var metric: GrowthMetric = .weight
    @State private var showMeasurementInput = false

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 20) {
                    ageModePicker(model: model)
                    metricPicker
                    chartCard
                    latestCard
                    addMeasurementCard
                    recordTrendCard
                }
                .padding(16)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("成長")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showMeasurementInput) {
                MeasurementInputView()
            }
        }
    }

    // 計測の入口をカードとして明示する（ツールバーの＋は気づきにくい）。
    private var addMeasurementCard: some View {
        Button {
            showMeasurementInput = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "ruler.fill")
                    .font(.title3).foregroundStyle(Theme.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("身長・体重・頭囲を記録する")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Text("健診や自宅での計測結果を追加")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Theme.brand)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // 「今日」で取っている記録の直近7日サマリー。
    private var recordTrendCard: some View {
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -7, to: .now)!
        let recent = model.logs.filter { $0.time >= since }
        func n(_ kinds: [CareKind]) -> Int { recent.filter { kinds.contains($0.kind) }.count }
        let feeds = n([.feeding, .bottle])
        let poops = n([.poop])
        let pees = n([.pee, .diaper])
        let sleeps = recent.filter { $0.kind == .sleep }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("この1週間の記録")
                .font(.headline)
            HStack(spacing: 8) {
                trendTile("授乳・ミルク", feeds, "回", .feeding)
                trendTile("睡眠", sleeps, "回", .sleep)
                trendTile("うんち", poops, "回", .poop)
                trendTile("おしっこ", pees, "回", .pee)
            }
            Text("1日あたり 授乳・ミルク 約\(feeds / 7)回、うんち 約\(poops / 7)回")
                .font(.caption).foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func trendTile(_ title: String, _ value: Int, _ unit: String, _ kind: CareKind) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("\(value)").font(.title3.weight(.bold)).foregroundStyle(kind.tint)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // 修正月齢/暦月齢トグル（§4.3.2: どちらで見ているか常時明示）
    private func ageModePicker(model: AppModel) -> some View {
        HStack {
            Label(model.useCorrectedAge ? "修正月齢で表示中" : "暦月齢で表示中",
                  systemImage: "calendar")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: Binding(get: { model.useCorrectedAge }, set: { model.useCorrectedAge = $0 })) {
                Text("暦").tag(false)
                Text("修正").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
        .cardStyle()
    }

    private var metricPicker: some View {
        Picker("指標", selection: $metric) {
            ForEach(GrowthMetric.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 発育曲線

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(metric.title)（\(metric.unit)）")
                .font(.headline)

            Chart {
                // 3〜97 パーセンタイルの帯
                ForEach(metric.reference) { p in
                    AreaMark(
                        x: .value("月齢", p.month),
                        yStart: .value("下限", p.p3),
                        yEnd: .value("上限", p.p97)
                    )
                    .foregroundStyle(Theme.brand.opacity(0.14))
                    .interpolationMethod(.catmullRom)
                }
                // 中央値(50)の目安線
                ForEach(metric.reference) { p in
                    LineMark(
                        x: .value("月齢", p.month),
                        y: .value("中央", p.p50)
                    )
                    .foregroundStyle(Theme.brand.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .interpolationMethod(.catmullRom)
                }
                // 自分の子の計測点
                ForEach(model.measurements) { m in
                    PointMark(
                        x: .value("月齢", m.ageMonths),
                        y: .value(metric.title, metric.value(m))
                    )
                    .foregroundStyle(Theme.brand)
                    .symbolSize(90)
                }
                // 点をつなぐ変化の向き
                ForEach(model.measurements) { m in
                    LineMark(
                        x: .value("月齢", m.ageMonths),
                        y: .value(metric.title, metric.value(m))
                    )
                    .foregroundStyle(Theme.brand)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxisLabel("月齢")
            .chartXScale(domain: 0...12)
            .frame(height: 240)

            // §4.3.3: 帯全体が正常範囲であることを常時テキストで併記
            Label("3〜97 パーセンタイルの帯全体が正常の範囲です。ひとつの点だけで判断せず、変化の向きを見てください。",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .cardStyle()
    }

    private var latestCard: some View {
        let latest = model.measurements.max { $0.ageMonths < $1.ageMonths }
        return VStack(alignment: .leading, spacing: 12) {
            Text("最新の計測")
                .font(.headline)
            HStack(spacing: 12) {
                statTile("身長", latest.map { String(format: "%.1f", $0.heightCm) } ?? "—", "cm")
                statTile("体重", latest.map { String(format: "%.1f", $0.weightKg) } ?? "—", "kg")
                statTile("頭囲", latest.map { String(format: "%.1f", $0.headCm) } ?? "—", "cm")
            }
        }
        .cardStyle()
    }

    private func statTile(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.bold)).foregroundStyle(Theme.brand)
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

// MARK: - 指標と参照値

enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight, height, head
    var id: String { rawValue }

    var title: String {
        switch self { case .weight: "体重"; case .height: "身長"; case .head: "頭囲" }
    }
    var unit: String {
        switch self { case .weight: "kg"; case .height: "cm"; case .head: "cm" }
    }
    func value(_ m: Measurement) -> Double {
        switch self { case .weight: m.weightKg; case .height: m.heightCm; case .head: m.headCm }
    }

    /// 男児 0〜12ヶ月のパーセンタイル参照値（表示確認用の概算値）。
    /// 実装時は母子健康手帳と同一の公表値に差し替えること（§4.3.1）。
    var reference: [PercentilePoint] {
        switch self {
        case .weight:
            return zip3(
                [2.5,3.5,4.4,5.1,5.6,6.1,6.4,6.7,7.0,7.2,7.4,7.6,7.7],
                [3.0,4.5,5.6,6.4,7.0,7.5,7.9,8.3,8.6,8.9,9.2,9.4,9.6],
                [3.8,5.7,7.0,7.9,8.6,9.2,9.7,10.2,10.5,10.9,11.2,11.5,11.8])
        case .height:
            return zip3(
                [46.0,50.9,54.5,57.5,59.9,61.9,63.6,65.0,66.3,67.4,68.4,69.4,70.3],
                [49.0,54.5,58.1,61.0,63.3,65.2,66.9,68.3,69.6,70.8,71.9,72.9,73.8],
                [52.0,58.0,61.7,64.5,66.8,68.7,70.4,71.9,73.2,74.5,75.7,76.8,77.9])
        case .head:
            return zip3(
                [31.5,35.0,37.0,38.5,39.7,40.6,41.4,42.0,42.5,43.0,43.4,43.7,44.0],
                [33.5,37.0,39.1,40.6,41.8,42.8,43.5,44.1,44.6,45.1,45.5,45.8,46.1],
                [35.5,39.0,41.2,42.7,43.9,44.9,45.7,46.3,46.8,47.3,47.7,48.0,48.3])
        }
    }

    private func zip3(_ p3: [Double], _ p50: [Double], _ p97: [Double]) -> [PercentilePoint] {
        (0..<p3.count).map { PercentilePoint(month: Double($0), p3: p3[$0], p50: p50[$0], p97: p97[$0]) }
    }
}

struct PercentilePoint: Identifiable {
    let id = UUID()
    var month: Double
    var p3: Double
    var p50: Double
    var p97: Double
}

#Preview {
    GrowthView(navPath: .constant(NavigationPath()))
        .environment(AppModel())
}
