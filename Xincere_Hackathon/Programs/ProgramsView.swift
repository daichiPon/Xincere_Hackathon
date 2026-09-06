import SwiftUI

/// S-10 区の制度一覧。世帯に登録した区を初期選択し、他区にも切り替えられる。
/// §7.2: 断定しない表現・出典必須。金額や可否の最終確認は窓口、という注記を必ず添える。
struct ProgramsView: View {
    @Environment(AppModel.self) private var model

    @State private var ward: String = ""
    @State private var toast: String?
    @State private var isGenerating = false

    private var grouped: [(category: String, items: [Program])] {
        Dictionary(grouping: model.programs, by: \.category)
            .map { (category: $0.key, items: $0.value.sorted { $0.programName < $1.programName }) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                wardPicker

                if model.isLoadingPrograms {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if model.programs.isEmpty {
                    ContentUnavailableView(
                        "この区の制度が見つかりません",
                        systemImage: "tray",
                        description: Text("時間をおいて再度お試しください。")
                    )
                    .padding(.top, 40)
                } else {
                    generateCard
                    ForEach(grouped, id: \.category) { group in
                        categorySection(group.category, group.items)
                    }
                    disclaimer
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground.ignoresSafeArea())
        .navigationTitle("区の制度")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: ward) {
            guard !ward.isEmpty else { return }
            await model.fetchPrograms(ward: ward)
        }
        .onAppear {
            if ward.isEmpty { ward = TokyoWard.normalized(model.municipality) }
        }
        .overlay(alignment: .bottom) {
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
            Text("締切のある制度を「やること」に追加")
                .font(.subheadline.weight(.semibold))
            Text("\(ward)で申請期限がある制度を、担当者未割当のやることとしてまとめて追加します。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task {
                    isGenerating = true
                    let msg = await model.generateTasksFromPrograms(ward: ward)
                    isGenerating = false
                    showToast(msg)
                }
            } label: {
                HStack {
                    if isGenerating { ProgressView().tint(.white) }
                    Text(isGenerating ? "追加中…" : "やることに追加")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(isGenerating)
        }
        .cardStyle()
    }

    private func categorySection(_ category: String, _ items: [Program]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category)
                .font(.headline)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, program in
                    NavigationLink {
                        ProgramDetailView(program: program)
                    } label: {
                        ProgramRow(program: program)
                    }
                    .buttonStyle(.plain)
                    if index < items.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
        }
    }

    private var disclaimer: some View {
        Text("掲載内容は区の公式ページをもとにしています。受給の可否・金額・締切は必ず各区の窓口でご確認ください。")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
            .padding(.top, 4)
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toast = nil }
        }
    }
}

private struct ProgramRow: View {
    let program: Program

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.programName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if program.hasDeadlineFlag {
                        Label("締切あり", systemImage: "calendar.badge.exclamationmark")
                            .foregroundStyle(Theme.warn)
                    }
                    if !program.amountOrContent.isEmpty {
                        Text(program.amountOrContent)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ProgramsView().environment(AppModel())
    }
}
