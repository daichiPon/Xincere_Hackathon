import SwiftUI

/// S-12 RAG 回答。回答本文＋出典カード。出典必須（§4.7.2）。
struct RagAnswerCard: View {
    let answer: AskAnswer
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("回答", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.brand)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
            }

            Text(answer.body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if answer.sources.isEmpty {
                Label("確かな出典が見つからないため、断定は避けています。",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Divider()
                Text("出典")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(answer.sources) { source in
                    SourceCard(source: source)
                }
            }
        }
        .cardStyle()
    }
}

struct SourceCard: View {
    let source: KnowledgeSource

    var body: some View {
        Group {
            if let url = URL(string: source.url) {
                Link(destination: url) { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(Theme.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                Text("\(source.publisher)・\(source.fetchedAt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Theme.brandSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    RagAnswerCard(answer: AskAnswer(
        body: "児童手当は、出生の翌日から15日以内に認定請求をすると、原則として申請月の翌月分から支給されます。",
        sources: [KnowledgeSource(title: "渋谷区 児童手当のご案内", publisher: "渋谷区", fetchedAt: "2026年8月20日時点", url: "https://example.com")]
    ), onClose: {})
    .padding()
}
