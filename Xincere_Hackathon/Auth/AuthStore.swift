import Foundation

/// 認証トークンと世帯情報を UserDefaults に永続化する。
@Observable
final class AuthStore {
    var token: String?
    var userId: String?
    var householdId: String?

    var isAuthenticated: Bool { token != nil && householdId != nil }

    init() {
        token       = UserDefaults.standard.string(forKey: "xincere.token")
        userId      = UserDefaults.standard.string(forKey: "xincere.userId")
        householdId = UserDefaults.standard.string(forKey: "xincere.householdId")
    }

    func save(token: String, userId: String, householdId: String) {
        self.token       = token
        self.userId      = userId
        self.householdId = householdId
        UserDefaults.standard.set(token,       forKey: "xincere.token")
        UserDefaults.standard.set(userId,      forKey: "xincere.userId")
        UserDefaults.standard.set(householdId, forKey: "xincere.householdId")
    }

    /// 世帯参加でトークンと世帯IDだけ差し替える。
    func updateHousehold(token: String, householdId: String) {
        self.token = token
        self.householdId = householdId
        UserDefaults.standard.set(token, forKey: "xincere.token")
        UserDefaults.standard.set(householdId, forKey: "xincere.householdId")
    }

    func logout() {
        token = nil; userId = nil; householdId = nil
        ["xincere.token", "xincere.userId", "xincere.householdId", "xincere.inviteCode"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
