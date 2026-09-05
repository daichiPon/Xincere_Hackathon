import SwiftUI

@main
struct XincereApp: App {
    @State private var model = AppModel()
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isAuthenticated {
                    RootTabView()
                        .task {
                            // 認証済みなら起動時にサーバーと同期
                            if let token = authStore.token {
                                model.configure(token: token)
                                model.inviteCode = authStore.inviteCode
                                await model.syncAll()
                            }
                        }
                } else {
                    LoginView()
                }
            }
            .environment(model)
            .environment(authStore)
        }
    }
}
