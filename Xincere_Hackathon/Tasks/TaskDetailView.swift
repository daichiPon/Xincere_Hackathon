import SwiftUI

/// S-09 手続き詳細。何のための手続きか→必要書類→窓口→出典リンク→時点。
/// §7.2: 断定しない表現、出典必須、誤り報告導線。§10.1: 完了はUndo可能。
struct TaskDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID

    @State private var showAssigneeDialog = false
    @State private var showReportDialog = false
    @State private var showDeleteDialog = false

    private var task: ProcedureTask? {
        model.tasks.first { $0.id == taskID }
    }

    var body: some View {
        Group {
            if let task {
                content(task)
            } else {
                ContentUnavailableView("この手続きは見つかりません", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle("手続きの詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(_ task: ProcedureTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(task)
                dueDateSection(task)
                summarySection(task)
                documentsSection(task)
                counterSection(task)
                sourceSection(task)
                actionButtons(task)
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .confirmationDialog("担当を選ぶ", isPresented: $showAssigneeDialog, titleVisibility: .visible) {
            ForEach(Assignee.allCases) { a in
                Button(a.rawValue) { updateAssignee(a) }
            }
        }
        .confirmationDialog("このやることを一覧から外しますか?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("一覧から外す", role: .destructive) {
                if let task { model.deleteTask(task) }
                dismiss()
            }
        }
        .alert("情報の報告", isPresented: $showReportDialog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この情報が古い・間違っているという報告を受け付けました。運営が確認します。")
        }
    }

    private func header(_ task: ProcedureTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.brandSoft, in: Capsule())
            Text(task.title)
                .font(.title2.weight(.bold))
            if let due = task.dueDate, task.status != .done {
                Label(due.formatted(date: .long, time: .omitted) + " まで",
                      systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(task.status == .dueSoon ? Theme.warn : .secondary)
            }
        }
    }

    @State private var editingDue = false
    @State private var dueDraft = Date.now

    private func dueDateSection(_ task: ProcedureTask) -> some View {
        section("予定日") {
            VStack(alignment: .leading, spacing: 10) {
                if editingDue {
                    DatePicker("予定日", selection: $dueDraft, displayedComponents: .date)
                        .labelsHidden()
                    HStack {
                        Button("キャンセル") { editingDue = false }.buttonStyle(.bordered)
                        Spacer()
                        Button("保存") {
                            Task { await model.setDueDate(task, to: dueDraft) }
                            editingDue = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    HStack {
                        Text(task.dueDate.map { $0.formatted(.dateTime.year().month().day()) } ?? "未定")
                            .font(.subheadline)
                        Spacer()
                        Button(task.dueDate == nil ? "日付を決める" : "変更") {
                            dueDraft = task.dueDate ?? Calendar.current.date(byAdding: .day, value: 14, to: .now)!
                            editingDue = true
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func summarySection(_ task: ProcedureTask) -> some View {
        section("この手続きについて") {
            Text(task.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func documentsSection(_ task: ProcedureTask) -> some View {
        section("必要書類") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(task.documents, id: \.self) { doc in
                    Label(doc, systemImage: "doc.text")
                        .font(.subheadline)
                }
            }
        }
    }

    private func counterSection(_ task: ProcedureTask) -> some View {
        section("窓口") {
            VStack(alignment: .leading, spacing: 10) {
                Label(task.counter, systemImage: "building.columns")
                    .font(.subheadline)
                Label(task.onlineAvailable ? "オンライン申請できます" : "窓口・郵送での申請です",
                      systemImage: task.onlineAvailable ? "checkmark.circle" : "envelope")
                    .font(.subheadline)
                    .foregroundStyle(task.onlineAvailable ? Theme.sage : .secondary)
            }
        }
    }

    // 出典必須（§4.5.4 / §7.2）
    private func sourceSection(_ task: ProcedureTask) -> some View {
        section("出典") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: task.sourceURL) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text(task.sourceTitle).lineLimit(2)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.brand)
                    }
                }
                Text(task.fetchedAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showReportDialog = true
                } label: {
                    Label("この情報が古い / 間違っている", systemImage: "exclamationmark.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("最終的な受給可否や金額は窓口でご確認ください。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func actionButtons(_ task: ProcedureTask) -> some View {
        VStack(spacing: 12) {
            Button {
                showAssigneeDialog = true
            } label: {
                Label(task.assignee == .unassigned ? "担当を決める" : "担当: \(task.assignee.rawValue)",
                      systemImage: task.assignee.symbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(Theme.brand)
            }

            Button {
                toggleDone(task)
            } label: {
                Label(task.status == .done ? "完了を取り消す" : "完了にする",
                      systemImage: task.status == .done ? "arrow.uturn.backward" : "checkmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(task.status == .done ? Color.secondary : Theme.brand,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Button(role: .destructive) {
                showDeleteDialog = true
            } label: {
                Label("一覧から外す", systemImage: "trash")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 部品 / 更新

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func updateAssignee(_ assignee: Assignee) {
        guard let idx = model.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        model.tasks[idx].assignee = assignee
    }

    private func toggleDone(_ task: ProcedureTask) {
        guard let idx = model.tasks.firstIndex(where: { $0.id == taskID }) else { return }
        if model.tasks[idx].status == .done {
            model.tasks[idx].status = task.dueDate != nil ? .scheduled : .scheduled
        } else {
            model.tasks[idx].status = .done
        }
    }
}

#Preview {
    let model = AppModel()
    return NavigationStack {
        TaskDetailView(taskID: model.tasks[0].id)
    }
    .environment(model)
}
