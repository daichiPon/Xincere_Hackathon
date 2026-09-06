import SwiftUI

/// S-12 予防接種の詳細。全国共通の標準スケジュール。
/// 「やることに追加」すると 誕生日 + 推奨月齢 を期限にしたタスクが作られる。
struct VaccineDetailView: View {
    @Environment(AppModel.self) private var model
    let vaccine: Vaccine

    @State private var toast: String?

    private var isAdded: Bool { model.isTaskAdded(vaccine: vaccine) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                addButton
                section("接種時期の目安") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(vaccine.timingText, systemImage: "calendar")
                            .font(.subheadline)
                        if !vaccine.intervalNote.isEmpty {
                            Label(vaccine.intervalNote, systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                section("予防できる病気") {
                    Text(vaccine.disease).font(.subheadline)
                }
                section("区分") {
                    Label(
                        vaccine.isRoutine ? "定期接種(対象年齢内は公費)" : "任意接種(区の助成がある場合あり)",
                        systemImage: vaccine.isRoutine ? "checkmark.seal" : "yensign.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(vaccine.isRoutine ? Theme.sage : .secondary)
                }
                if !vaccine.notes.isEmpty {
                    section("補足") {
                        Text(vaccine.notes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                section("出典") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let url = URL(string: vaccine.sourceUrl) {
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
                        Text("取得日: \(vaccine.fetchedAt)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("接種の可否・時期は、区から届く予診票とかかりつけ医の案内に従ってください。")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .navigationTitle("予防接種の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Theme.brand, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(vaccine.isRoutine ? "定期接種" : "任意接種")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Theme.brandSoft, in: Capsule())
            Text(vaccine.title).font(.title2.weight(.bold))
        }
    }

    @ViewBuilder
    private var addButton: some View {
        if isAdded {
            Label("「やること」に追加済み", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.sage)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            AsyncButton("「やること」に追加") {
                let msg = await model.addTask(fromVaccine: vaccine)
                withAnimation { toast = msg }
                Task { try? await Task.sleep(for: .seconds(3)); withAnimation { toast = nil } }
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
        VaccineDetailView(vaccine: Vaccine(
            id: "1", vaccineName: "5種混合", doseLabel: "1回目", doseNumber: 1,
            category: "定期", disease: "ジフテリア・百日せき・破傷風・ポリオ・ヒブ感染症",
            startAgeMonths: 2, endAgeMonths: nil,
            intervalNote: "前回から20〜56日あける",
            notes: "2024年4月に定期接種化。従来の4種混合+ヒブの後継",
            sourceUrl: "https://www.mhlw.go.jp/", fetchedAt: "2026-09-06"
        ))
        .environment(AppModel())
    }
}
