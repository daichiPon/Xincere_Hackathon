import SwiftUI

/// 各画面ヘッダに常設する「緊急時」ボタン（§10.2）。
struct EmergencyButton: View {
    @State private var showEmergency = false

    var body: some View {
        Button {
            showEmergency = true
        } label: {
            Label("緊急時", systemImage: "cross.case.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.warn)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.warn.opacity(0.14), in: Capsule())
        }
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyTriageView()
        }
    }
}

// MARK: - トリアージ（S-13 / S-14）

/// 緊急時トリアージ。§10.4 に従い装飾ゼロ・1 画面 1 問・大きな選択肢。
struct EmergencyTriageView: View {
    @Environment(\.dismiss) private var dismiss

    /// 判断の分岐。到達点は 3 つ（救急要請 / 今すぐ受診 / 様子見+再評価）。
    enum Node {
        case q1, q2, q3
        case emergency   // 救急要請
        case seeNow      // 今すぐ受診
        case observe     // 様子見 + 再評価
    }

    @State private var node: Node = .q1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                switch node {
                case .q1:
                    question("ぐったりして、\n呼びかけへの反応が\n鈍いですか？",
                             yes: .emergency, no: .q2)
                case .q2:
                    question("生後3か月未満で、\n38℃以上の発熱が\nありますか？",
                             yes: .seeNow, no: .q3)
                case .q3:
                    question("水分がとれず、\n半日以上おしっこが\n出ていませんか？",
                             yes: .seeNow, no: .observe)
                case .emergency:
                    result(
                        title: "ためらわず 119",
                        message: "意識・呼吸に関わる可能性があります。すぐに救急要請してください。",
                        primaryLabel: "119 に電話",
                        primaryNumber: "119",
                        tint: Theme.warn
                    )
                case .seeNow:
                    result(
                        title: "今すぐ受診・相談を",
                        message: "受診の判断に迷うときは、小児救急電話相談 #8000 に電話してください。",
                        primaryLabel: "#8000 に電話",
                        primaryNumber: "8000",
                        tint: Color.orange
                    )
                case .observe:
                    result(
                        title: "自宅で様子を見る",
                        message: "水分をこまめに与え、2〜3時間ごとに様子を再確認してください。悪化したら受診してください。",
                        primaryLabel: "#8000 に相談",
                        primaryNumber: "8000",
                        tint: Theme.sage
                    )
                }

                Spacer(minLength: 0)

                // §10.4: すべての分岐に「迷ったら相談」を残す。
                if isQuestion {
                    Text("判断に迷う場合は #8000 または 119")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }

    private var isQuestion: Bool {
        switch node { case .q1, .q2, .q3: true; default: false }
    }

    private var header: some View {
        HStack {
            if !isQuestion {
                Button {
                    node = .q1
                } label: {
                    Label("最初から", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.top, 12)
    }

    // 質問画面
    private func question(_ text: String, yes: Node, no: Node) -> some View {
        VStack(spacing: 32) {
            Text(text)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 16) {
                bigButton("はい", tint: Theme.warn) {
                    withAnimation(.snappy) { node = yes }
                }
                bigButton("いいえ", tint: Color.white.opacity(0.14)) {
                    withAnimation(.snappy) { node = no }
                }
            }
        }
    }

    // 結論画面
    private func result(title: String, message: String, primaryLabel: String, primaryNumber: String, tint: Color) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            // 結論画面では「電話をかける」を最大の要素にする。
            Link(destination: URL(string: "tel://\(primaryNumber)")!) {
                Label(primaryLabel, systemImage: "phone.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            Text("この結果は診断ではありません。判断に迷うときは受診してください。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private func bigButton(_ title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
                .background(tint, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

#Preview("トリアージ") {
    EmergencyTriageView()
}
