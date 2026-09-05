import Foundation

/// 認証トークンと世帯情報を UserDefaults に永続化する。
@Observable
final class AuthStore {
    var token: String?
    var userId: String?
    var householdId: String?
    var inviteCode: String?

    var isAuthenticated: Bool { token != nil && householdId != nil }

    init() {
        token       = UserDefaults.standard.string(forKey: "xincere.token")
        userId      = UserDefaults.standard.string(forKey: "xincere.userId")
        householdId = UserDefaults.standard.string(forKey: "xincere.householdId")
        inviteCode  = UserDefaults.standard.string(forKey: "xincere.inviteCode")
    }

    func save(token: String, userId: String, householdId: String, inviteCode: String?) {
        self.token       = token
        self.userId      = userId
        self.householdId = householdId
        self.inviteCode  = inviteCode
        UserDefaults.standard.set(token,       forKey: "xincere.token")
        UserDefaults.standard.set(userId,      forKey: "xincere.userId")
        UserDefaults.standard.set(householdId, forKey: "xincere.householdId")
        if let code = inviteCode {
            UserDefaults.standard.set(code, forKey: "xincere.inviteCode")
        }
    }

    func logout() {
        token = nil; userId = nil; householdId = nil; inviteCode = nil
        ["xincere.token", "xincere.userId", "xincere.householdId", "xincere.inviteCode"]
            .forEach { UserDefaults.standard.removeObject(forKey: $0) }
    }
}
