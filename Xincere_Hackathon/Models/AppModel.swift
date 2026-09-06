import SwiftUI
import Observation

// MARK: - 記録

enum CareKind: String, CaseIterable, Identifiable {
    case feeding      // 授乳（母乳）
    case bottle       // ミルク
    case sleep        // 睡眠
    case diaper       // おむつ
    case temperature  // 体温

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feeding:     "授乳"
        case .bottle:      "ミルク"
        case .sleep:       "睡眠"
        case .diaper:      "おむつ"
        case .temperature: "体温"
        }
    }

    var symbol: String {
        switch self {
        case .feeding:     "drop.fill"
        case .bottle:      "waterbottle.fill"
        case .sleep:       "moon.zzz.fill"
        case .diaper:      "square.stack.3d.up.fill"
        case .temperature: "thermometer.medium"
        }
    }

    var tint: Color {
        switch self {
        case .feeding:     Theme.brand
        case .bottle:      Theme.sage
        case .sleep:       Color(red: 0.50, green: 0.47, blue: 0.68)
        case .diaper:      Color(red: 0.68, green: 0.58, blue: 0.42)
        case .temperature: Theme.warn
        }
    }

    static let quickActions: [CareKind] = [.feeding, .bottle, .sleep, .diaper]
}

struct CareLog: Identifiable {
    var id: UUID
    var kind: CareKind
    var time: Date
    var detail: String

    init(id: UUID = UUID(), kind: CareKind, time: Date = .now, detail: String) {
        self.id = id; self.kind = kind; self.time = time; self.detail = detail
    }
}

// MARK: - 計測

struct Measurement: Identifiable {
    var id: UUID
    var ageMonths: Double
    var date: Date
    var heightCm: Double
    var weightKg: Double
    var headCm: Double

    init(id: UUID = UUID(), ageMonths: Double, date: Date, heightCm: Double, weightKg: Double, headCm: Double) {
        self.id = id; self.ageMonths = ageMonths; self.date = date
        self.heightCm = heightCm; self.weightKg = weightKg; self.headCm = headCm
    }
}

struct Milestone: Identifiable {
    let id = UUID()
    var title: String
    var range: String
}

// MARK: - やること

enum ProcedureStatus: String {
    case dueSoon   = "dueSoon"
    case scheduled = "scheduled"
    case done      = "done"
}

enum Assignee: String, CaseIterable, Identifiable {
    case me        = "わたし"
    case partner   = "パートナー"
    case unassigned = "未割当"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .me:         "person.crop.circle.fill"
        case .partner:    "person.crop.circle.badge.checkmark"
        case .unassigned: "person.crop.circle.badge.questionmark"
        }
    }

    var serverKey: String {
        switch self {
        case .me: "me"; case .partner: "partner"; case .unassigned: "unassigned"
        }
    }

    static func from(serverKey: String) -> Assignee {
        switch serverKey {
        case "me": .me; case "partner": .partner; default: .unassigned
        }
    }
}

struct ProcedureTask: Identifiable {
    var id: UUID
    var title: String
    var category: String
    var dueDate: Date?
    var status: ProcedureStatus
    var assignee: Assignee
    var summary: String
    var documents: [String]
    var counter: String
    var onlineAvailable: Bool
    var sourceTitle: String
    var sourceURL: String
    var fetchedAt: String

    init(
        id: UUID = UUID(), title: String, category: String, dueDate: Date? = nil,
        status: ProcedureStatus, assignee: Assignee, summary: String, documents: [String],
        counter: String, onlineAvailable: Bool, sourceTitle: String, sourceURL: String, fetchedAt: String
    ) {
        self.id = id; self.title = title; self.category = category; self.dueDate = dueDate
        self.status = status; self.assignee = assignee; self.summary = summary
        self.documents = documents; self.counter = counter; self.onlineAvailable = onlineAvailable
        self.sourceTitle = sourceTitle; self.sourceURL = sourceURL; self.fetchedAt = fetchedAt
    }
}

// MARK: - きく

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
    var birthDate = Calendar.current.date(byAdding: .day, value: -132, to: .now)!
    var isPreterm = false
    var municipality = "渋谷区"
    var useCorrectedAge = false
    var inviteCode: String?

    // 記録（F-2）
    var logs: [CareLog]

    // 授乳タイマー
    var feedingStart: Date?
    var feedingSide: FeedingSide = .left
    enum FeedingSide: String { case left = "左", right = "右" }

    // 睡眠タイマー
    var sleepStart: Date?

    // 計測（F-3）
    var measurements: [Measurement]
    var milestones: [Milestone]

    // やること（F-4）
    var tasks: [ProcedureTask]

    // 区の制度一覧（F-5）
    var programs: [Program] = []
    var programsWard: String = ""
    var isLoadingPrograms = false

    // 予防接種スケジュール（F-5）
    var vaccines: [Vaccine] = []

    // ネットワーク
    var apiClient: APIClient?
    var isSyncing = false
    var syncError: String?

    // MARK: - Computed

    var recentLogs: [CareLog] { logs.sorted { $0.time > $1.time } }

    var actionableTaskCount: Int { tasks.filter { $0.status == .dueSoon }.count }

    var lastFeeding: CareLog? {
        logs.filter { $0.kind == .feeding || $0.kind == .bottle }.max { $0.time < $1.time }
    }

    var ageText: String {
        let comps = Calendar.current.dateComponents([.month, .day], from: birthDate, to: .now)
        return "生後 \(comps.month ?? 0)ヶ月\(comps.day ?? 0)日"
    }

    var ageMonths: Double {
        let days = Calendar.current.dateComponents([.day], from: birthDate, to: .now).day ?? 0
        return Double(days) / 30.4
    }

    // MARK: - ネットワーク設定

    func configure(token: String) {
        apiClient = APIClient(token: token)
    }

    /// サーバーから全データを取得してローカルを置き換える。
    func syncAll() async {
        guard let client = apiClient else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            async let logsTask: [CareLogResponse]        = client.get("/api/logs")
            async let measurementsTask: [MeasurementResponse] = client.get("/api/measurements")
            async let householdTask: HouseholdResponse   = client.get("/api/household")

            let (logResults, measurementResults, household) =
                try await (logsTask, measurementsTask, householdTask)

            logs = logResults.compactMap { r in
                guard let kind = CareKind(rawValue: r.kind) else { return nil }
                return CareLog(
                    id: UUID(uuidString: r.id) ?? UUID(),
                    kind: kind,
                    time: Date(timeIntervalSince1970: Double(r.time) / 1000),
                    detail: r.detail
                )
            }

            measurements = measurementResults.map { r in
                Measurement(
                    id: UUID(uuidString: r.id) ?? UUID(),
                    ageMonths: r.ageMonths,
                    date: Date(timeIntervalSince1970: Double(r.date) / 1000),
                    heightCm: r.heightCm,
                    weightKg: r.weightKg,
                    headCm: r.headCm
                )
            }

            childName   = household.childName
            birthDate   = Date(timeIntervalSince1970: Double(household.birthDate) / 1000)
            isPreterm   = household.isPreterm != 0
            if !household.municipality.isEmpty { municipality = household.municipality }
            inviteCode  = household.inviteCode

            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }

        await syncTasks()
    }

    /// サーバーの procedure_tasks をローカルの tasks に反映する。
    func syncTasks() async {
        guard let client = apiClient else { return }
        do {
            let results: [TaskResponse] = try await client.get("/api/tasks")
            tasks = results.map { r in
                let docs = (try? JSONDecoder().decode([String].self, from: Data(r.documents.utf8))) ?? []
                return ProcedureTask(
                    id: UUID(uuidString: r.id) ?? UUID(),
                    title: r.title,
                    category: r.category,
                    dueDate: r.dueDate.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                    status: ProcedureStatus(rawValue: r.status) ?? .scheduled,
                    assignee: Assignee.from(serverKey: r.assignee),
                    summary: r.summary,
                    documents: docs,
                    counter: r.counter,
                    onlineAvailable: r.onlineAvailable != 0,
                    sourceTitle: r.sourceTitle,
                    sourceURL: r.sourceUrl,
                    fetchedAt: r.fetchedAt
                )
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    // MARK: - 区の制度

    /// 指定した区の制度一覧を取得する。
    func fetchPrograms(ward: String) async {
        guard let client = apiClient else { return }
        isLoadingPrograms = true
        defer { isLoadingPrograms = false }
        do {
            var comps = URLComponents()
            comps.path = "/api/programs"
            comps.queryItems = [URLQueryItem(name: "ward", value: ward)]
            let path = comps.string ?? "/api/programs"
            let resp: ProgramListResponse = try await client.get(path)
            programs = resp.items
            programsWard = ward
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// 世帯の区の「締切あり制度」から、やることタスクを生成する。
    /// 成功時はユーザー向けの結果メッセージ、失敗時はエラーメッセージを返す。
    func generateTasksFromPrograms(ward: String? = nil) async -> String {
        guard let client = apiClient else { return "ログインが必要です" }
        do {
            struct Body: Encodable { let ward: String? }
            let resp: GenerateTasksResponse = try await client.post(
                "/api/tasks/generate", body: Body(ward: ward)
            )
            await syncTasks()
            if resp.created == 0 {
                return "追加できる新しいやることはありませんでした"
            }
            return "\(resp.ward)の制度から \(resp.created)件のやることを追加しました"
        } catch {
            return error.localizedDescription
        }
    }

    /// 制度1件を「やること」に追加する。
    func addTask(fromProgram program: Program) async -> String {
        guard let client = apiClient else { return "ログインが必要です" }
        do {
            struct Body: Encodable { let programId: String }
            let resp: AddTaskResponse = try await client.post(
                "/api/tasks/from-program", body: Body(programId: program.id)
            )
            await syncTasks()
            return resp.alreadyExists == true ? "すでに追加されています" : "「\(program.programName)」をやることに追加しました"
        } catch {
            return error.localizedDescription
        }
    }

    /// この制度がすでにやることに入っているか。
    func isTaskAdded(program: Program) -> Bool {
        tasks.contains { $0.title == program.programName && $0.sourceURL == program.sourceUrl }
    }

    // MARK: - 予防接種

    func fetchVaccines() async {
        guard let client = apiClient, vaccines.isEmpty else { return }
        do {
            let resp: VaccineListResponse = try await client.get("/api/vaccines")
            vaccines = resp.items
        } catch {
            syncError = error.localizedDescription
        }
    }

    /// 予防接種1件を「やること」に追加する(期限=誕生日+推奨月齢)。
    func addTask(fromVaccine vaccine: Vaccine) async -> String {
        guard let client = apiClient else { return "ログインが必要です" }
        do {
            struct Body: Encodable { let vaccineId: String }
            let resp: AddTaskResponse = try await client.post(
                "/api/tasks/from-vaccine", body: Body(vaccineId: vaccine.id)
            )
            await syncTasks()
            return resp.alreadyExists == true ? "すでに追加されています" : "「\(vaccine.title)」をやることに追加しました"
        } catch {
            return error.localizedDescription
        }
    }

    func isTaskAdded(vaccine: Vaccine) -> Bool {
        tasks.contains { $0.title == vaccine.title && $0.category == "予防接種" }
    }

    // MARK: - 記録操作

    func addLog(_ kind: CareKind, detail: String, time: Date = .now) {
        let log = CareLog(kind: kind, time: time, detail: detail)
        logs.append(log)
        guard let client = apiClient else { return }
        let localId = log.id
        Task {
            do {
                struct Body: Encodable { let kind: String; let timeMs: Int; let detail: String }
                let resp: CareLogResponse = try await client.post("/api/logs", body: Body(
                    kind: kind.rawValue,
                    timeMs: Int(time.timeIntervalSince1970 * 1000),
                    detail: detail
                ))
                if let idx = logs.firstIndex(where: { $0.id == localId }),
                   let sid = UUID(uuidString: resp.id) {
                    logs[idx].id = sid
                }
            } catch { /* ローカルデータをそのまま保持 */ }
        }
    }

    func deleteLog(_ log: CareLog) {
        let id = log.id
        logs.removeAll { $0.id == id }
        guard let client = apiClient else { return }
        Task { try? await client.delete("/api/logs/\(id.uuidString.lowercased())") }
    }

    // MARK: - 計測操作

    func addMeasurement(ageMonths: Double, date: Date, heightCm: Double, weightKg: Double, headCm: Double) {
        let m = Measurement(ageMonths: ageMonths, date: date, heightCm: heightCm, weightKg: weightKg, headCm: headCm)
        measurements.append(m)
        guard let client = apiClient else { return }
        let localId = m.id
        Task {
            do {
                struct Body: Encodable {
                    let ageMonths: Double; let dateMs: Int
                    let heightCm: Double; let weightKg: Double; let headCm: Double
                }
                let resp: MeasurementResponse = try await client.post("/api/measurements", body: Body(
                    ageMonths: ageMonths,
                    dateMs: Int(date.timeIntervalSince1970 * 1000),
                    heightCm: heightCm, weightKg: weightKg, headCm: headCm
                ))
                if let idx = measurements.firstIndex(where: { $0.id == localId }),
                   let sid = UUID(uuidString: resp.id) {
                    measurements[idx].id = sid
                }
            } catch {}
        }
    }

    // MARK: - タスク操作

    func updateTaskStatus(_ task: ProcedureTask, status: ProcedureStatus) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].status = status
        guard let client = apiClient else { return }
        let id = task.id
        Task {
            struct Body: Encodable { let status: String }
            let _: TaskResponse = try await client.put(
                "/api/tasks/\(id.uuidString.lowercased())",
                body: Body(status: status.rawValue)
            )
        }
    }

    func updateTaskAssignee(_ task: ProcedureTask, assignee: Assignee) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].assignee = assignee
        guard let client = apiClient else { return }
        let id = task.id
        Task {
            struct Body: Encodable { let assignee: String }
            let _: TaskResponse = try await client.put(
                "/api/tasks/\(id.uuidString.lowercased())",
                body: Body(assignee: assignee.serverKey)
            )
        }
    }

    // MARK: - タイマー

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

    var isSleeping: Bool { sleepStart != nil }

    func toggleSleep() {
        if let start = sleepStart {
            let minutes = max(1, Int(Date.now.timeIntervalSince(start) / 60))
            let h = minutes / 60
            let m = minutes % 60
            addLog(.sleep, detail: h > 0 ? "\(h)時間\(m)分" : "\(m)分", time: start)
            sleepStart = nil
        } else {
            sleepStart = .now
        }
    }

    // MARK: - 初期サンプルデータ（未認証時表示用）

    init() {
        let now = Date.now
        func ago(_ min: Int) -> Date { now.addingTimeInterval(TimeInterval(-min * 60)) }

        logs = [
            CareLog(kind: .feeding,     time: ago(135), detail: "左 12分"),
            CareLog(kind: .diaper,      time: ago(215), detail: "おしっこ"),
            CareLog(kind: .sleep,       time: ago(300), detail: "1時間40分"),
            CareLog(kind: .bottle,      time: ago(430), detail: "120ml"),
            CareLog(kind: .temperature, time: ago(560), detail: "36.8℃"),
        ]

        measurements = [
            Measurement(ageMonths: 0, date: ago(60*24*132), heightCm: 49.2, weightKg: 3.1, headCm: 33.5),
            Measurement(ageMonths: 1, date: ago(60*24*100), heightCm: 54.0, weightKg: 4.4, headCm: 37.0),
            Measurement(ageMonths: 2, date: ago(60*24*70),  heightCm: 58.1, weightKg: 5.6, headCm: 39.2),
            Measurement(ageMonths: 3, date: ago(60*24*40),  heightCm: 61.0, weightKg: 6.3, headCm: 40.5),
            Measurement(ageMonths: 4, date: ago(60*24*5),   heightCm: 63.4, weightKg: 6.9, headCm: 41.6),
        ]

        milestones = [
            Milestone(title: "首がすわる",       range: "3〜4ヶ月ごろ"),
            Milestone(title: "寝返りをする",      range: "5〜6ヶ月ごろ"),
            Milestone(title: "声を出して笑う",    range: "3〜4ヶ月ごろ"),
            Milestone(title: "あやすと反応する",  range: "2〜4ヶ月ごろ"),
        ]

        let cal = Calendar.current
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now)! }

        tasks = [
            ProcedureTask(
                title: "児童手当の認定請求", category: "給付金", dueDate: day(4), status: .dueSoon,
                assignee: .unassigned,
                summary: "出生の翌日から15日以内に申請すると、原則として出生月の翌月分から支給されます。遅れると遡って支給されない月が出る場合があります。",
                documents: ["請求者名義の口座がわかるもの", "請求者の健康保険証", "本人確認書類", "マイナンバーがわかるもの"],
                counter: "渋谷区 子ども青少年課", onlineAvailable: true,
                sourceTitle: "渋谷区 児童手当のご案内",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kodomo/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "乳幼児医療費助成の申請", category: "医療", dueDate: day(9), status: .dueSoon,
                assignee: .me,
                summary: "対象年齢の子の医療費自己負担分が助成されます。健康保険への加入後に申請します。",
                documents: ["子の健康保険証", "保護者の本人確認書類"],
                counter: "渋谷区 国保年金課", onlineAvailable: false,
                sourceTitle: "渋谷区 子ども医療費助成",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kodomo/iryohijosei.html",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "出生届", category: "届出", dueDate: nil, status: .done,
                assignee: .partner,
                summary: "出生の日から14日以内に提出します。",
                documents: ["出生証明書", "母子健康手帳", "届出人の本人確認書類"],
                counter: "渋谷区 戸籍住民課", onlineAvailable: false,
                sourceTitle: "渋谷区 出生届",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kurashi/koseki/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "1か月児健診", category: "健診", dueDate: day(21), status: .scheduled,
                assignee: .me,
                summary: "体重・身長の計測と発育の確認を行います。相談したいことリストを事前に用意できます。",
                documents: ["母子健康手帳", "受診票"],
                counter: "出産した医療機関", onlineAvailable: false,
                sourceTitle: "渋谷区 乳幼児健診",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kenko/kenshin/",
                fetchedAt: "2026年8月20日時点"
            ),
            ProcedureTask(
                title: "四種混合（1回目）予防接種", category: "予防接種", dueDate: day(35), status: .scheduled,
                assignee: .unassigned,
                summary: "定期接種の標準的な開始時期に入りました。かかりつけ医で予約できます。",
                documents: ["母子健康手帳", "予診票"],
                counter: "指定医療機関", onlineAvailable: true,
                sourceTitle: "渋谷区 予防接種",
                sourceURL: "https://www.city.shibuya.tokyo.jp/kenko/yobo/",
                fetchedAt: "2026年8月20日時点"
            ),
        ]
    }
}
