import SwiftUI
import Combine

/// S-03 ホーム（今日）。§10.3 ①今日 の設計に従う。
/// 「最後の授乳から」を最大表示、記録は 2×2 グリッド、下部に直近ログ。
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Binding var navPath: NavigationPath
    @State private var showFeedingTimer = false
    @State private var showBottleInput = false
    @State private var showTempInput = false
    @State private var showProfile = false
    @State private var bottleAmountML = 120
    @State private var tempValue = 36.8
    @State private var quickToast: String?

    // 1 秒ごとに経過時間表示を更新する。
    @State private var now = Date.now
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(spacing: 20) {
                    elapsedCard
                    quickGrid
                    todayTally
                    recentSection
                }
                .padding(16)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("今日")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.childName).font(.headline)
                        Text(model.ageText).font(.caption).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProfile = true } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.brand)
                    }
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showFeedingTimer) {
                FeedingTimerView()
            }
            .sheet(isPresented: $showBottleInput) {
                BottleInputView(amountML: $bottleAmountML) { amount in
                    model.addLog(.bottle, detail: "\(amount)ml")
                    showToast("ミルク \(amount)ml を記録しました")
                }
            }
            .sheet(isPresented: $showTempInput) {
                TemperatureInputView(value: $tempValue) { t in
                    model.addLog(.temperature, detail: String(format: "%.1f℃", t))
                    showToast(String(format: "体温 %.1f℃ を記録しました", t))
                }
            }
            .overlay(alignment: .bottom) {
                if let quickToast {
                    UndoToast(text: quickToast) {
                        if let last = model.recentLogs.first { model.deleteLog(last) }
                        withAnimation { self.quickToast = nil }
                    }
                    .padding(.bottom, 8)
                }
            }
            .onReceive(ticker) { now = $0 }
        }
    }

    // MARK: - 経過時間カード

    private var elapsedCard: some View {
        VStack(spacing: 6) {
            Text("最後の授乳から")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(elapsedText)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.brand)
            if let last = model.lastFeeding {
                Text("\(last.time.formatted(date: .omitted, time: .shortened))  \(last.kind.title) \(last.detail)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(Theme.brandSoft)
        )
    }

    private var elapsedText: String {
        guard let last = model.lastFeeding else { return "—" }
        let interval = max(0, now.timeIntervalSince(last.time))
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return h > 0 ? "\(h)時間\(m)分" : "\(m)分"
    }

    // MARK: - 2×2 クイック記録

    private var quickGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(CareKind.quickActions) { kind in
                QuickRecordButton(
                    kind: kind,
                    isRunning: (kind == .feeding && model.isFeeding) || (kind == .sleep && model.isSleeping)
                ) {
                    tapQuick(kind)
                }
            }
        }
    }

    private func tapQuick(_ kind: CareKind) {
        switch kind {
        case .feeding:
            showFeedingTimer = true
        case .bottle:
            showBottleInput = true
        case .sleep:
            model.toggleSleep()
            showToast(model.isSleeping ? "睡眠を開始しました" : "睡眠を記録しました")
        case .pee:
            model.addLog(.pee, detail: "おしっこ")
            showToast("おしっこを記録しました")
        case .poop:
            model.addLog(.poop, detail: "うんち")
            showToast("うんちを記録しました")
        case .temperature:
            showTempInput = true
        case .diaper:
            break
        }
    }

    // MARK: - 今日のまとめ

    private var todayTally: some View {
        let cal = Calendar.current
        let todays = model.logs.filter { cal.isDateInToday($0.time) }
        func count(_ ks: [CareKind]) -> Int { todays.filter { ks.contains($0.kind) }.count }
        return HStack(spacing: 8) {
            tallyTile("授乳・ミルク", count([.feeding, .bottle]), .feeding)
            tallyTile("睡眠", count([.sleep]), .sleep)
            tallyTile("うんち", count([.poop]), .poop)
            tallyTile("おしっこ", count([.pee, .diaper]), .pee)
        }
    }

    private func tallyTile(_ title: String, _ n: Int, _ kind: CareKind) -> some View {
        VStack(spacing: 4) {
            Image(systemName: kind.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(kind.tint)
            Text("\(n)").font(.headline.monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func showToast(_ text: String) {
        withAnimation { quickToast = text }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation { if quickToast == text { quickToast = nil } }
        }
    }

    // MARK: - 直近ログ

    private var recentSection: some View {
        let cal = Calendar.current
        let todays = model.recentLogs.filter { cal.isDateInToday($0.time) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("今日の記録")
                .font(.headline)
                .padding(.horizontal, 4)

            if todays.isEmpty {
                Text("まだ今日の記録はありません。上のボタンから記録できます。")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todays.enumerated()), id: \.element.id) { index, log in
                        NavigationLink {
                            LogEditView(log: log)
                        } label: {
                            LogRow(log: log)
                        }
                        .buttonStyle(.plain)
                        if index < todays.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .cardStyle(padding: 8)
            }
        }
    }
}

// MARK: - 体温入力

private struct TemperatureInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var value: Double
    let onRecord: (Double) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()
                VStack(spacing: 8) {
                    Text(String(format: "%.1f", value))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(value >= 37.5 ? Theme.warn : Theme.brand)
                    Text("℃").font(.title2).foregroundStyle(.secondary)
                }
                Stepper("", value: $value, in: 35.0...42.0, step: 0.1)
                    .labelsHidden().scaleEffect(1.3)
                Spacer()
            }
            .padding(24)
            .background(Theme.screenBackground)
            .navigationTitle("体温記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録") { onRecord(value); dismiss() }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 部品

private struct QuickRecordButton: View {
    let kind: CareKind
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: isRunning ? "stop.fill" : kind.symbol)
                    .font(.system(size: 30, weight: .semibold))
                Text(isRunning ? (kind == .sleep ? "睡眠中…" : "授乳中…") : kind.title)
                    .font(.headline)
            }
            .foregroundStyle(kind.tint)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.minTapSize + 12)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .fill(isRunning ? kind.tint.opacity(0.22) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .stroke(isRunning ? kind.tint : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LogRow: View {
    let log: CareLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.kind.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(log.kind.tint)
                .frame(width: 36, height: 36)
                .background(log.kind.tint.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(log.kind.title).font(.subheadline.weight(.medium))
                Text(log.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(log.time.formatted(date: .omitted, time: .shortened))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

/// 破壊的操作は確認ダイアログではなく Undo で解決する（§10.1）。
struct UndoToast: View {
    let text: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(text).font(.subheadline).foregroundStyle(.white)
            Spacer()
            Button("取り消す", action: onUndo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.brand)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.black.opacity(0.85), in: Capsule())
        .padding(.horizontal, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - ミルク量入力

private struct BottleInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var amountML: Int
    let onRecord: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 8) {
                    Text("\(amountML)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.sage)
                    Text("ml")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Stepper("", value: $amountML, in: 10...400, step: 10)
                    .labelsHidden()
                    .scaleEffect(1.3)

                Spacer()
            }
            .padding(24)
            .background(Theme.screenBackground)
            .navigationTitle("ミルク記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("記録") {
                        onRecord(amountML)
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    TodayView(navPath: .constant(NavigationPath()))
        .environment(AppModel())
        .environment(AuthStore())
}
