import SwiftUI
import Combine

/// S-04 授乳記録。開始でタイマーが走り、停止で確定。左右切替はタイマー中に表示。
struct FeedingTimerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var now = Date.now
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 36) {
                Spacer()

                Text(elapsed)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(model.isFeeding ? Theme.brand : .primary)

                // 左右切替（タイマー中のみ）
                if model.isFeeding {
                    sideSwitcher
                }

                Spacer()

                Button {
                    let wasFeeding = model.isFeeding
                    model.toggleFeeding()
                    if wasFeeding { dismiss() }
                } label: {
                    Text(model.isFeeding ? "停止して記録" : "授乳を開始")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .background(model.isFeeding ? Theme.warn : Theme.brand,
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(24)
            .background(Theme.screenBackground)
            .navigationTitle("授乳")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onReceive(ticker) { now = $0 }
        }
        .presentationDetents([.medium, .large])
    }

    private var sideSwitcher: some View {
        HStack(spacing: 12) {
            ForEach([AppModel.FeedingSide.left, .right], id: \.rawValue) { side in
                Button {
                    model.feedingSide = side
                } label: {
                    Text(side.rawValue)
                        .font(.title3.weight(.semibold))
                        .frame(width: 96, height: 64)
                        .foregroundStyle(model.feedingSide == side ? .white : Theme.brand)
                        .background(model.feedingSide == side ? Theme.brand : Theme.brandSoft,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var elapsed: String {
        guard let start = model.feedingStart else { return "0:00" }
        let interval = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d", interval / 60, interval % 60)
    }
}

/// S-05 記録編集。時刻を遡って修正・削除できる。
struct LogEditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    let log: CareLog
    @State private var time: Date
    @State private var detail: String

    init(log: CareLog) {
        self.log = log
        _time = State(initialValue: log.time)
        _detail = State(initialValue: log.detail)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: log.kind.symbol)
                        .foregroundStyle(log.kind.tint)
                    Text(log.kind.title).font(.headline)
                }
            }
            Section("時刻") {
                DatePicker("記録時刻", selection: $time, in: ...Date.now)
                    .datePickerStyle(.compact)
            }
            Section("内容") {
                TextField("内容", text: $detail)
            }
            Section {
                Button(role: .destructive) {
                    model.deleteLog(log)
                    dismiss()
                } label: {
                    Label("この記録を削除", systemImage: "trash")
                }
            }
        }
        .navigationTitle("記録の編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    model.deleteLog(log)
                    model.addLog(log.kind, detail: detail, time: time)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    FeedingTimerView()
        .environment(AppModel())
}
