import SwiftUI

/// S-08c 自分たちの予定を「やること」に手動で追加する。
struct AddTaskView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var category = "予定"
    @State private var hasDueDate = true
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
    @State private var assignee: Assignee = .unassigned
    @State private var summary = ""
    @State private var saving = false
    @State private var error: String?

    private let categories = ["予定", "健診", "予防接種", "届出", "給付金", "その他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("内容") {
                    TextField("やること（例: 3-4か月健診）", text: $title)
                    Picker("カテゴリ", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                }
                Section("期限") {
                    Toggle("期限を設定する", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("期限", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("担当") {
                    Picker("担当", selection: $assignee) {
                        ForEach(Assignee.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("メモ（任意）") {
                    TextField("持ち物・場所など", text: $summary, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("やることを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }

    private func save() {
        saving = true
        error = nil
        Task {
            let err = await model.createTask(
                title: title.trimmingCharacters(in: .whitespaces),
                category: category,
                dueDate: hasDueDate ? dueDate : nil,
                assignee: assignee,
                summary: summary.trimmingCharacters(in: .whitespaces)
            )
            saving = false
            if let err { error = err } else { dismiss() }
        }
    }
}

#Preview {
    AddTaskView().environment(AppModel())
}
