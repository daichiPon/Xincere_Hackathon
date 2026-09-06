import SwiftUI

/// S-11 制度の詳細。内容→対象→締切→申請方法→必要書類→出典→時点、の順。
/// §7.2: 断定を避け、出典を必須で示し、最終確認は窓口へ誘導する。
struct ProgramDetailView: View {
    let program: Program

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                contentSection
                targetSection
                deadlineSection
                applicationSection
                if !program.documentList.isEmpty { documentsSection }
                if !program.notes.isEmpty { notesSection }
                sourceSection
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .navigationTitle("制度の詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(program.ward) ・ \(program.category)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.brandSoft, in: Capsule())
            Text(program.programName)
                .font(.title2.weight(.bold))
        }
    }

    private var contentSection: some View {
        section("内容") {
            VStack(alignment: .leading, spacing: 8) {
                if !program.amountOrContent.isEmpty {
                    Text(program.amountOrContent).font(.subheadline)
                }
                if !program.programType.isEmpty {
                    Label(program.programType, systemImage: "yensign.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var targetSection: some View {
        section("対象") {
            VStack(alignment: .leading, spacing: 8) {
                Label(program.incomeCondition.isEmpty ? "所得条件の記載なし" : program.incomeCondition,
                      systemImage: "person.text.rectangle")
                    .font(.subheadline)
                if let range = program.ageRangeText {
                    Label("対象月齢の目安: \(range)", systemImage: "calendar")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var deadlineSection: some View {
        section("締切") {
            if program.hasDeadlineFlag {
                Label(program.deadlineRule.isEmpty ? "申請期限あり(詳細は窓口で確認)" : program.deadlineRule,
                      systemImage: "calendar.badge.exclamationmark")
                    .font(.subheadline)
                    .foregroundStyle(Theme.warn)
            } else {
                Label("随時申請できます(明確な締切なし)", systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.sage)
            }
        }
    }

    private var applicationSection: some View {
        section("申請方法") {
            VStack(alignment: .leading, spacing: 8) {
                if !program.applicationChannel.isEmpty {
                    Label(program.applicationChannel, systemImage: "building.columns")
                        .font(.subheadline)
                }
                Label(program.canApplyOnline ? "オンライン申請できます" : "窓口・郵送での申請です",
                      systemImage: program.canApplyOnline ? "checkmark.circle" : "envelope")
                    .font(.subheadline)
                    .foregroundStyle(program.canApplyOnline ? Theme.sage : .secondary)
            }
        }
    }

    private var documentsSection: some View {
        section("必要書類") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(program.documentList, id: \.self) { doc in
                    Label(doc, systemImage: "doc.text").font(.subheadline)
                }
            }
        }
    }

    private var notesSection: some View {
        section("補足") {
            Text(program.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceSection: some View {
        section("出典") {
            VStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: program.sourceUrl) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "link")
                            Text("公式ページを開く")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.brand)
                    }
                }
                Text("取得日: \(program.fetchedAt)")
                    .font(.caption).foregroundStyle(.secondary)
                Text("最終的な受給可否・金額・締切は各区の窓口でご確認ください。")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    NavigationStack {
        ProgramDetailView(program: Program(
            id: "1", ward: "世田谷区", category: "紙おむつ・育児用品支給",
            programName: "子育ておむつ定期便", minAgeMonths: 0, maxAgeMonths: 12,
            incomeCondition: "なし", programType: "現物給付",
            amountOrContent: "毎月おむつ等を自宅に配送(生後11か月まで)",
            applicationChannel: "オンライン or 窓口", requiredDocuments: "母子健康手帳、本人確認書類",
            hasDeadline: 1, deadlineRule: "満1歳になるまで",
            sourceUrl: "https://www.city.setagaya.lg.jp/", fetchedAt: "2026-09-06",
            notes: "訪問時に育児相談も受けられる"
        ))
    }
}
