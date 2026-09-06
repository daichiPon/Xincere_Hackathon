import Foundation

// MARK: - 東京23区

enum TokyoWard {
    /// 区の一覧(北・東からおおむね時計回り)。区の選択ピッカーで使う。
    static let all: [String] = [
        "千代田区", "中央区", "港区", "新宿区", "文京区", "台東区", "墨田区", "江東区",
        "品川区", "目黒区", "大田区", "世田谷区", "渋谷区", "中野区", "杉並区", "豊島区",
        "北区", "荒川区", "板橋区", "練馬区", "足立区", "葛飾区", "江戸川区",
    ]

    /// 未設定・区外の値を弾いて、有効な区名か既定値を返す。
    static func normalized(_ value: String?) -> String {
        guard let value, all.contains(value) else { return all[0] }
        return value
    }
}

// MARK: - 制度マスタ(program_master)

/// 区の子育て支援制度の1件。`GET /api/programs` のレスポンス要素。
/// APIClient は `.convertFromSnakeCase` なのでサーバの snake_case をそのまま受けられる。
struct Program: Identifiable, Decodable, Hashable {
    let id: String
    let ward: String
    let category: String
    let programName: String
    let minAgeMonths: Int?
    let maxAgeMonths: Int?
    let incomeCondition: String
    let programType: String
    let amountOrContent: String
    let applicationChannel: String
    let requiredDocuments: String
    let hasDeadline: Int
    let deadlineRule: String
    let sourceUrl: String
    let fetchedAt: String
    let notes: String

    var hasDeadlineFlag: Bool { hasDeadline != 0 }
    var canApplyOnline: Bool { applicationChannel.contains("オンライン") }

    /// 「〇〇、△△」形式の必要書類を配列に割る。
    var documentList: [String] {
        requiredDocuments
            .split(whereSeparator: { "、・,/／\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var ageRangeText: String? {
        switch (minAgeMonths, maxAgeMonths) {
        case (nil, nil): return nil
        case let (lo?, hi?): return "\(lo)〜\(hi)ヶ月"
        case let (lo?, nil): return "\(lo)ヶ月〜"
        case let (nil, hi?): return "〜\(hi)ヶ月"
        }
    }
}

struct ProgramListResponse: Decodable {
    let total: Int
    let items: [Program]
}

struct GenerateTasksResponse: Decodable {
    let ward: String
    let created: Int
    let skipped: Int
}
