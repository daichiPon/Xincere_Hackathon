import SwiftUI

/// S-11 きく（トップ）。§10.3 ④きく に従い、空の入力欄ではなく質問チップを先に見せる。
/// 医療的な質問を検知したら回答せず緊急時トリアージへ遷移する（§4.7.2）。
struct AskView: View {
    @Environment(AppModel.self) private var model
    @Binding var navPath: NavigationPath
    @State private var query = ""
    @State private var answer: AskAnswer?
    @State private var routeToEmergency = false

    // 月齢に応じて出すチップ（生後4ヶ月想定）。
    private let chips = [
        "授乳の間隔はどれくらい？",
        "児童手当はいつ申請する？",
        "予防接種の同時接種は大丈夫？",
        "うんちの回数が減った",
        "そろそろ離乳食？",
        "乳幼児医療費助成の対象は？",
    ]

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let answer {
                        RagAnswerCard(answer: answer) {
                            withAnimation { self.answer = nil }
                        }
                    }

                    guideSection

                    Text("よくある質問")
                        .font(.headline)

                    // 質問チップ
                    FlowChips(items: chips) { chip in
                        ask(chip)
                    }

                    milestonesSection
                }
                .padding(16)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("きく")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(text: $query, prompt: "制度や育児のことを調べる")
            .onSubmit(of: .search) { ask(query) }
            .fullScreenCover(isPresented: $routeToEmergency) {
                EmergencyTriageView()
            }
        }
    }

    // ④きく / 緊急時ガイド / 医療機関検索への入口
    private var guideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("こまったときは")
                .font(.headline)
                .padding(.top, 4)

            Button {
                routeToEmergency = true
            } label: {
                guideRow(icon: "cross.case.fill", tint: Theme.warn,
                         title: "緊急時ガイド",
                         subtitle: "夜間・救急の判断（オフラインでも使えます）")
            }
            .buttonStyle(.plain)

            NavigationLink {
                ClinicFinderView()
            } label: {
                guideRow(icon: "cross.fill", tint: Theme.brand,
                         title: "医療機関を探す",
                         subtitle: "近くの小児科・夜間休日診療")
            }
            .buttonStyle(.plain)
        }
    }

    // 今の時期の目安（成長タブから移設。達成チェックではなく目安）
    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今の時期の目安")
                .font(.headline)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(model.milestones) { m in
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Theme.sage)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(.subheadline.weight(.medium))
                            Text("\(m.range)　※まだの場合も個人差の範囲です")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .cardStyle()
        }
    }

    private func guideRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - 意図分類（簡易）

    private func ask(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        query = ""

        // 医療判断はRAGを通さず緊急時トリアージへ強制ルーティング。
        let medicalKeywords = ["熱", "発熱", "けいれん", "ぐったり", "誤飲", "嘔吐", "呼吸", "救急", "薬"]
        if medicalKeywords.contains(where: q.contains) {
            routeToEmergency = true
            return
        }

        withAnimation { answer = makeAnswer(for: q) }
    }

    // 保持データに基づく限定回答（デモ用の固定応答）。
    private func makeAnswer(for q: String) -> AskAnswer {
        if q.contains("児童手当") {
            return AskAnswer(
                body: "児童手当は、出生の翌日から15日以内に認定請求をすると、原則として申請月の翌月分から支給されます。渋谷区では子ども青少年課が窓口です。詳しい金額や所得の条件は窓口でご確認ください。",
                sources: [KnowledgeSource(title: "渋谷区 児童手当のご案内", publisher: "渋谷区", fetchedAt: "2026年8月20日時点", url: "https://www.city.shibuya.tokyo.jp/kodomo/")]
            )
        }
        if q.contains("医療費") {
            return AskAnswer(
                body: "乳幼児医療費助成は、健康保険に加入している対象年齢の子の医療費自己負担分を助成する制度です。健康保険への加入後に申請できます。対象範囲は自治体により異なるため、窓口でご確認ください。",
                sources: [KnowledgeSource(title: "渋谷区 子ども医療費助成", publisher: "渋谷区", fetchedAt: "2026年8月20日時点", url: "https://www.city.shibuya.tokyo.jp/kodomo/iryohijosei.html")]
            )
        }
        // 根拠がない場合は答えない（§4.7.2）。
        return AskAnswer(
            body: "この質問に確実にお答えできる情報が、いまアプリの中に見つかりませんでした。育児一般のことは、お住まいの保健センターや#8000（小児救急電話相談）に相談できます。制度のことは「やること」タブの各手続きの出典リンクもご確認ください。",
            sources: []
        )
    }
}

// MARK: - チップの折り返しレイアウト

struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.subheadline)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(Theme.card, in: Capsule())
                        .overlay(Capsule().stroke(Theme.brand.opacity(0.3), lineWidth: 1))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// チップを行方向に折り返す簡易レイアウト。
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    AskView(navPath: .constant(NavigationPath()))
        .environment(AppModel())
}
