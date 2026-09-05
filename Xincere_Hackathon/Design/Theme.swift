import SwiftUI

/// アプリ全体のデザイントークン。
/// §10.5 のトーン&マナーに従い、低彩度を基本とし警告色は緊急時と期限にのみ用いる。
/// ダークモード優先で設計しつつ、システムカラーで両モードに追従させる。
enum Theme {

    // MARK: - Color

    /// 落ち着いた青系のブランドカラー。プライマリアクションに用いる。
    static let brand = Color(red: 0.36, green: 0.53, blue: 0.72)

    /// ブランドカラーの淡い面。カードの背景ハイライトなどに用いる。
    static let brandSoft = Color(red: 0.36, green: 0.53, blue: 0.72).opacity(0.16)

    /// 成長・記録の補助アクセント（低彩度のセージグリーン）。
    static let sage = Color(red: 0.44, green: 0.60, blue: 0.55)

    /// 警告色。緊急時と期限にのみ使用する。
    static let warn = Color(red: 0.82, green: 0.38, blue: 0.36)

    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    // MARK: - Metric

    /// 片手操作のための最小タップ領域（§10.3 の記録ボタン要件）。
    static let minTapSize: CGFloat = 88
    static let cornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 18
}

extension View {
    /// 標準的なカード見た目を付与する。
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}
