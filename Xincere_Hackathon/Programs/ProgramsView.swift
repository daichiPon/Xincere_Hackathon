import SwiftUI

/// S-10 子育て支援を調べる。制度(区ごと)と予防接種(全国共通)を切り替えて一覧する。
/// 各項目は詳細画面から「やることに追加」できる。
/// §7.2: 断定しない表現・出典必須。金額や可否の最終確認は窓口、という注記を必ず添える。
struct ProgramsView: View {
    @Environment(AppModel.self) private var model

    enum Tab: String, CaseIterable { case programs = "制度・給付金", vaccines = "予防接種" }

    @State private var tab: Tab = .programs
    @State private var ward: String = ""
    @State private var toast: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Picker("表示", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .programs: programsContent
                case .vaccines: vaccinesContent
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("子育て支援を調べる")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ward) {
            guard tab == .programs, !ward.isEmpty else { return }
            await model.fetchPrograms(ward: ward)
        }
        .task { await model.fetchVaccines() }
        .onAppear {
            if ward.isEmpty { ward = TokyoWard.normalized(model.municipality) }
        }
        .overlay(alignment: .bottom) { toastView }
    }

    // MARK: - 制度

    private var programsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            wardPicker

            if model.isLoadingPrograms {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else if model.programs.isEmpty {
                ContentUnavailableView("この区の制度が見つかりません", systemImage: "tray")
                    .padding(.top, 40)
            } else {
                generateCard
                ForEach(programGroups, id: \.category) { group in
                    listSection(group.category, count: group.items.count) {
                        ForEach(group.items) { program in
                            NavigationLink { ProgramDetailView(program: program) } label: {
                                catalogRow(
                                    title: program.programName,
                                    subtitle: program.amountOrContent,
                                    flag: program.hasDeadlineFlag ? "締切あり" : nil,
                                    added: model.isTaskAdded(program: program)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                disclaimer
            }
        }
    }

    private var programGroups: [(category: String, items: [Program])] {
        Dictionary(grouping: model.programs, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.programName < $1.programName }) }
            .sorted { $0.category < $1.category }
    }

    private var wardPicker: some View {
        Menu {
            Picker("区", selection: $ward) {
                ForEach(TokyoWard.all, id: \.self) { Text($0).tag($0) }
            }
        } label: {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                Text(ward.isEmpty ? "区を選ぶ" : ward).font(.headline)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
                Spacer()
            }
            .foregroundStyle(Theme.brand)
            .cardStyle()
        }
    }

    private var generateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("締切のある制度をまとめて「やること」に追加")
                .font(.subheadline.weight(.semibold))
            Text("\(ward)で申請期限がある制度を、担当者未割当のやることとして一括で追加します。")
                .font(.caption).foregroundStyle(.secondary)
            AsyncButton("おすすめをまとめて追加") {
                showToast(await model.generateTasksFromPrograms(ward: ward))
            }
        }
        .cardStyle()
    }

    // MARK: - 予防接種

    private var vaccinesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("国が定める標準的な接種スケジュールです。実際の時期は区から届く予診票と、かかりつけ医の案内に従ってください。")
                .font(.caption).foregroundStyle(.secondary)

            if model.vaccines.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ForEach(vaccineGroups, id: \.bucket) { group in
                    listSection(group.bucket, count: group.items.count) {
                        ForEach(group.items) { vaccine in
                            NavigationLink { VaccineDetailView(vaccine: vaccine) } label: {
                                catalogRow(
                                    title: vaccine.title,
                                    subtitle: "\(vaccine.timingText)・\(vaccine.disease)",
                                    flag: vaccine.isRoutine ? nil : "任意",
                                    added: model.isTaskAdded(vaccine: vaccine)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var vaccineGroups: [(bucket: String, items: [Vaccine])] {
        let order = ["0歳(生後2〜11か月)", "1歳", "2〜5歳", "6歳以降", "その他"]
        return Dictionary(grouping: model.vaccines, by: \.ageBucket)
            .map { (bucket: $0.key, items: $0.value.sorted {
                ($0.startAgeMonths ?? 999) != ($1.startAgeMonths ?? 999)
                    ? ($0.startAgeMonths ?? 999) < ($1.startAgeMonths ?? 999)
                    : $0.vaccineName < $1.vaccineName
            }) }
            .sorted { (order.firstIndex(of: $0.bucket) ?? 99) < (order.firstIndex(of: $1.bucket) ?? 99) }
    }

    // MARK: - 共通部品

    private func listSection<Content: View>(
        _ title: String, count: Int, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Text("\(count)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        }
    }

    private func catalogRow(title: String, subtitle: String, flag: String?, added: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if let flag {
                        Text(flag)
                            .foregroundStyle(Theme.warn)
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .font(.caption)
            }
            Spacer(minLength: 4)
            if added {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sage)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Divider().padding(.leading, 14) }
    }

    private var disclaimer: some View {
        Text("掲載内容は区の公式ページをもとにしています。受給の可否・金額・締切は必ず各区の窓口でご確認ください。")
            .font(.caption2).foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Theme.brand, in: Capsule())
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toast = nil }
        }
    }
}

/// 押すと非同期処理を走らせ、その間はスピナーを出すボタン。
struct AsyncButton: View {
    let title: String
    let action: () async -> Void
    @State private var running = false

    init(_ title: String, action: @escaping () async -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            Task { running = true; await action(); running = false }
        } label: {
            HStack {
                if running { ProgressView().tint(.white) }
                Text(running ? "処理中…" : title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(running)
    }
}

#Preview {
    NavigationStack {
        ProgramsView().environment(AppModel())
    }
}
