import SwiftUI

/// S-05b 時刻をさかのぼって記録する。タイマーを使わずに「さっきの分」を後から付ける。
struct ManualLogView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: CareKind = .feeding
    @State private var time = Date.now
    @State private var side: AppModel.FeedingSide = .left
    @State private var minutes = 10
    @State private var sleepHours = 1
    @State private var sleepMinutes = 30
    @State private var ml = 120
    @State private var temp = 36.8

    private let kinds: [CareKind] = [.feeding, .bottle, .sleep, .pee, .poop, .temperature]

    var body: some View {
        NavigationStack {
            Form {
                Section("種類") {
                    Picker("種類", selection: $kind) {
                        ForEach(kinds) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section("時刻") {
                    DatePicker("記録する時刻", selection: $time, in: ...Date.now)
                }

                detailSection
            }
            .navigationTitle("あとから記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録") {
                        model.addLog(kind, detail: detailText, time: time)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var detailSection: some View {
        switch kind {
        case .feeding:
            Section("授乳") {
                Picker("どちら", selection: $side) {
                    ForEach(AppModel.FeedingSide.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper("時間 \(minutes) 分", value: $minutes, in: 1...60)
            }
        case .bottle:
            Section("ミルク") {
                Stepper("量 \(ml) ml", value: $ml, in: 10...400, step: 10)
            }
        case .sleep:
            Section("睡眠") {
                Stepper("\(sleepHours) 時間", value: $sleepHours, in: 0...12)
                Stepper("\(sleepMinutes) 分", value: $sleepMinutes, in: 0...55, step: 5)
            }
        case .temperature:
            Section("体温") {
                Stepper(String(format: "%.1f ℃", temp), value: $temp, in: 35.0...42.0, step: 0.1)
            }
        case .pee, .poop, .diaper:
            EmptyView()
        }
    }

    private var detailText: String {
        switch kind {
        case .feeding:     return "\(side.rawValue) \(minutes)分"
        case .bottle:      return "\(ml)ml"
        case .sleep:       return sleepHours > 0 ? "\(sleepHours)時間\(sleepMinutes)分" : "\(sleepMinutes)分"
        case .temperature: return String(format: "%.1f℃", temp)
        case .pee:         return "おしっこ"
        case .poop:        return "うんち"
        case .diaper:      return "おむつ"
        }
    }
}

#Preview {
    ManualLogView().environment(AppModel())
}
