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

struct AddTaskResponse: Decodable {
    let created: Int
    let alreadyExists: Bool?
}

// MARK: - 予防接種スケジュール(vaccine_schedule)

/// 全国共通の標準接種スケジュール1件。`GET /api/vaccines` のレスポンス要素。
struct Vaccine: Identifiable, Decodable, Hashable {
    let id: String
    let vaccineName: String
    let doseLabel: String
    let doseNumber: Int
    let category: String        // 定期 / 任意
    let disease: String
    let startAgeMonths: Double?
    let endAgeMonths: Double?
    let intervalNote: String
    let notes: String
    let sourceUrl: String
    let fetchedAt: String

    var isRoutine: Bool { category == "定期" }
    var title: String { "\(vaccineName) \(doseLabel)" }

    /// 「生後2か月ごろ」「1歳ごろ」など、開始月齢のざっくり表示。
    var timingText: String {
        guard let m = startAgeMonths else { return "時期は要確認" }
        if m < 12 { return "生後\(Int(m))か月ごろ" }
        let years = m / 12
        if years == years.rounded() { return "\(Int(years))歳ごろ" }
        return "\(Int(m))か月ごろ"
    }

    /// 一覧のグルーピング用の月齢ブロック。
    var ageBucket: String {
        guard let m = startAgeMonths else { return "その他" }
        switch m {
        case ..<12: return "0歳(生後2〜11か月)"
        case ..<24: return "1歳"
        case ..<72: return "2〜5歳"
        default:    return "6歳以降"
        }
    }
}

struct VaccineListResponse: Decodable {
    let total: Int
    let items: [Vaccine]
}
