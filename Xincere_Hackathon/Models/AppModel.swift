import SwiftUI
import Observation

// MARK: - 記録

/// 日々の記録カテゴリ（F-2）。
enum CareKind: String, CaseIterable, Identifiable {
    case feeding      // 授乳（母乳）
    case bottle       // ミルク
    case sleep        // 睡眠
    case diaper       // おむつ
    case temperature  // 体温

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feeding: "授乳"
        case .bottle: "ミルク"
        case .sleep: "睡眠"
        case .diaper: "おむつ"
        case .temperature: "体温"
        }
    }

    var symbol: String {
        switch self {
        case .feeding: "drop.fill"
        case .bottle: "waterbottle.fill"
        case .sleep: "moon.zzz.fill"
        case .diaper: "square.stack.3d.up.fill"
        case .temperature: "thermometer.medium"
        }
    }

    var tint: Color {
        switch self {
        case .feeding: Theme.brand
        case .bottle: Theme.sage
        case .sleep: Color(red: 0.50, green: 0.47, blue: 0.68)
        case .diaper: Color(red: 0.68, green: 0.58, blue: 0.42)
        case .temperature: Theme.warn
        }
    }

    /// ホームの 2×2 クイック記録に出す 4 項目。
    static let quickActions: [CareKind] = [.feeding, .bottle, .sleep, .diaper]
}

/// 1 件の記録。追記型（§8.3）を意識し、編集より新規を基本とする。
struct CareLog: Identifiable {
    let id = UUID()
    var kind: CareKind
    var time: Date
    var detail: String
}

// MARK: - 計測（F-3）

struct Measurement: Identifiable {
    let id = UUID()
    /// 月齢（修正/暦は表示側で解釈）。
    var ageMonths: Double
    var date: Date
    var heightCm: Double
    var weightKg: Double
    var headCm: Double
}

/// 月齢別のマイルストーン。達成チェックではなく目安として提示する（§10.3 の注意）。
struct Milestone: Identifiable {
    let id = UUID()
    var title: String
    var range: String
}

// MARK: - やること（F-4 / F-8）

enum ProcedureStatus {
    case dueSoon   // 期限あり（赤系アクセント）
    case scheduled // 予定
    case done      // 完了（グレーアウト）
}

enum Assignee: String, CaseIterable, Identifiable {
    case me = "わたし"
    case partner = "パートナー"
    case unassigned = "未割当"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .me: "person.crop.circle.fill"
        case .partner: "person.crop.circle.badge.checkmark"
        case .unassigned: "person.crop.circle.badge.questionmark"
        }
    }
}

/// 手続きタスク（TaskInstance 相当）。出典必須（§7.2）。
struct ProcedureTask: Identifiable {
    let id = UUID()
    var title: String
    var category: String
    var dueDate: Date?
    var status: ProcedureStatus
    var assignee: Assignee
    var summary: String
    var documents: [String]
    var counter: String        // 窓口
    var onlineAvailable: Bool
    var sourceTitle: String
    var sourceURL: String
    var fetchedAt: String      // 「◯年◯月◯日時点」
}

// MARK: - きく（F-7）

struct KnowledgeSource: Identifiable {
    let id = UUID()
    var title: String
    var publisher: String
    var fetchedAt: String
    var url: String
}

struct AskAnswer {
    var body: String
    var sources: [KnowledgeSource]
}

// MARK: - アプリ状態

@Observable
final class AppModel {

    // 子・世帯プロファイル（F-1）
    var childName = "さくら"
    var birthDate = Calendar.current.date(byAdding: .day, value: -132, to: .now)! // 生後 4ヶ月12日
    var isPreterm = false
    var municipality = "渋谷区"
    var useCorrectedAge = false

    // 記録（F-2）
    var logs: [CareLog]

    // 授乳タイマー
    var feedingStart: Date?
    var feedingSide: FeedingSide = .left

    enum FeedingSide: String { case left = "左", right = "右" }

    // 計測（F-3）
    var measurements: [Measurement]
    var milestones: [Milestone]

    // やること（F-4）
    var tasks: [ProcedureTask]

    // 直近ログ（新しい順）
    var recentLogs: [CareLog] { logs.sorted { $0.time > $1.time } }

    /// 未完了かつ期限ありのタスク数。バッジは「やること」タブだけ（§10.2）。
    var actionableTaskCount: Int {
        tasks.filter { $0.status == .dueSoon }.count
    }

    var lastFeeding: CareLog? {
        logs.filter { $0.kind == .feeding || $0.kind == .bottle }
            .max { $0.time < $1.time }
    }

    var ageText: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthDate, to: .now)
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return "生後 \(m)ヶ月\(d)日"
    }

    var ageMonths: Double {
        let days = Calendar.current.dateComponents([.day], from: birthDate, to: .now).day ?? 0
        return Double(days) / 30.4
    }

    // MARK: - 操作

    func addLog(_ kind: CareKind, detail: String, time: Date = .now) {
        logs.append(CareLog(kind: kind, time: time, detail: detail))
    }

    func deleteLog(_ log: CareLog) {
        logs.removeAll { $0.id == log.id }
    }

    /// 授乳タイマーのトグル（開始→停止で記録を確定）。
    func toggleFeeding() {
        if let start = feedingStart {
            let minutes = max(1, Int(Date.now.timeIntervalSince(start) / 60))
            addLog(.feeding, detail: "\(feedingSide.rawValue) \(minutes)分", time: start)
            feedingStart = nil
        } else {
            feedingStart = .now
        }
    }

    var isFeeding: Bool { feedingStart != nil }

    // MARK: - 初期データ

    init() {
        let now = Date.now
        func ago(_ minutes: Int) -> Date { now.addingTimeInterval(TimeInterval(-minutes * 60)) }

        logs = [
            CareLog(kind: .feeding, time: ago(135), detail: "左 12分"),
            CareLog(kind: .diaper, time: ago(215), detail: "おしっこ"),
            CareLog(kind: .sleep, time: ago(300), detail: "1時間40分"),
            CareLog(kind: .bottle, time: ago(430), detail: "120ml"),
            CareLog(kind: .temperature, time: ago(560), detail: "36.8℃"),
        ]

        measurements = [
            Measurement(ageMonths: 0, date: ago(60 * 24 * 132), heightCm: 49.2, weightKg: 3.1, headCm: 33.5),
            Measurement(ageMonths: 1, date: ago(60 * 24 * 100), heightCm: 54.0, weightKg: 4.4, headCm: 37.0),
            Measurement(ageMonths: 2, date: ago(60 * 24 * 70), heightCm: 58.1, weightKg: 5.6, headCm: 39.2),
            Measurement(ageMonths: 3, date: ago(60 * 24 * 40), heightCm: 61.0, weightKg: 6.3, headCm: 40.5),
            Measurement(ageMonths: 4, date: ago(60 * 24 * 5), heightCm: 63.4, weightKg: 6.9, headCm: 41.6),
        ]

        milestones = [
            Milestone(title: "首がすわる", range: "3〜4ヶ月ごろ"),
            Milestone(title: "寝返りをする", range: "5〜6ヶ月ごろ"),
            Milestone(title: "声を出して笑う", range: "3〜4ヶ月ごろ"),
            Milestone(title: "あやすと反応する", range: "2〜4ヶ月ごろ"),
        ]

        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now)! }

        tasks = [
            ProcedureTask(
                title: "児童手当の認定請求",
                category: "給付金",
                dueDate: day(4),
                status: .dueSoon,
                assignee: .unassigned,
                summary: "出生の翌日から15日以内に申請すると、原則として出生月の翌月分から支給されます。遅れると遡って支給されない月が出る場合があります。",
                documents: ["請求者名義の口座がわかるもの", "請求者の健康保険証", "本人確認書類", "マイナンバーがわかるもの"],
                counter: "渋谷区 子ども青少年課",
                onlineAvailable: true,
                sourceTitle: "渋谷区 児童手当のご案内",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kodomo/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "乳幼児医療費助成の申請",
                category: "医療",
                dueDate: day(9),
                status: .dueSoon,
                assignee: .me,
                summary: "対象年齢の子の医療費自己負担分が助成されます。健康保険への加入後に申請します。",
                documents: ["子の健康保険証", "保護者の本人確認書類"],
                counter: "渋谷区 国保年金課",
                onlineAvailable: false,
                sourceTitle: "渋谷区 子ども医療費助成",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kodomo/iryohijosei.html",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "出生届",
                category: "届出",
                dueDate: nil,
                status: .done,
                assignee: .partner,
                summary: "出生の日から14日以内に提出します。",
                documents: ["出生証明書", "母子健康手帳", "届出人の本人確認書類"],
                counter: "渋谷区 戸籍住民課",
                onlineAvailable: false,
                sourceTitle: "渋谷区 出生届",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kurashi/koseki/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "1か月児健診",
                category: "健診",
                dueDate: day(21),
                status: .scheduled,
                assignee: .me,
                summary: "体重・身長の計測と発育の確認を行います。相談したいことリストを事前に用意できます。",
                documents: ["母子健康手帳", "受診票"],
                counter: "出産した医療機関",
                onlineAvailable: false,
                sourceTitle: "渋谷区 乳幼児健診",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kenko/kenshin/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "四種混合（1回目）予防接種",
                category: "予防接種",
                dueDate: day(35),
                status: .scheduled,
                assignee: .unassigned,
                summary: "定期接種の標準的な開始時期に入りました。かかりつけ医で予約できます。",
                documents: ["母子健康手帳", "予診票"],
                counter: "指定医療機関",
                onlineAvailable: true,
                sourceTitle: "渋谷区 予防接種",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kenko/yobo/",
                fetchedAt: "2026年8月20日時点"
            ),
        ]
    }
}
