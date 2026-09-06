import SwiftUI

private enum AuthMode: CaseIterable {
    case login, register, join

    var label: String {
        switch self {
        case .login:    "ログイン"
        case .register: "新規登録"
        case .join:     "招待参加"
        }
    }
}

/// ログイン・新規登録・招待コードによる参加を一画面にまとめる。
struct LoginView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(AppModel.self) private var model

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var ward = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // ヘッダー
                    VStack(spacing: 8) {
                        Image(systemName: "figure.and.child.holdinghands")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.brand)
                        Text("Xincere")
                            .font(.largeTitle.bold())
                        Text("家族の育児記録を、ひとつに")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    // モード切替
                    Picker("モード", selection: $mode) {
                        ForEach(AuthMode.allCases, id: \.self) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    // フォーム
                    VStack(spacing: 14) {
                        if mode != .join {
                            inputField("メールアドレス", text: $email, keyboard: .emailAddress)
                            inputField("パスワード", text: $password, isSecure: true)
                        }
                        if mode == .register || mode == .join {
                            inputField("名前", text: $name)
                        }
                        if mode == .register {
                            wardField
                        }
                        if mode == .join {
                            inputField("メールアドレス", text: $email, keyboard: .emailAddress)
                            inputField("パスワード（新規設定）", text: $password, isSecure: true)
                            inputField("招待コード（6文字）", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }

                    // エラー
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // 送信
                    Button(action: submit) {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(mode.label)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Theme.brand,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .disabled(isLoading || !formValid)

                    if mode == .join {
                        Text("パートナーのアプリ内「招待コード」を入力すると同じ世帯のデータを共有できます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    // MARK: - バリデーション

    private var formValid: Bool {
        switch mode {
        case .login:    !email.isEmpty && password.count >= 6
        case .register: !email.isEmpty && password.count >= 6 && !name.isEmpty && !ward.isEmpty
        case .join:     !name.isEmpty && !email.isEmpty && password.count >= 6 && inviteCode.count == 6
        }
    }

    // MARK: - 送信

    private func submit() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                switch mode {
                case .login:    try await doLogin()
                case .register: try await doRegister()
                case .join:     try await doJoin()
                }
            } catch let e as APIError {
                errorMessage = e.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func doLogin() async throws {
        struct Body: Encodable { let email: String; let password: String }
        let resp: AuthResponse = try await APIClient().post("/auth/login", body: Body(email: email, password: password))
        finalize(resp: resp, inviteCode: resp.inviteCode)
    }

    private func doRegister() async throws {
        struct Body: Encodable { let email: String; let password: String; let name: String; let municipality: String }
        let resp: AuthResponse = try await APIClient().post(
            "/auth/register",
            body: Body(email: email, password: password, name: name, municipality: ward)
        )
        model.municipality = ward
        finalize(resp: resp, inviteCode: resp.inviteCode)
    }

    private func doJoin() async throws {
        struct RegBody: Encodable { let email: String; let password: String; let name: String }
        let reg: AuthResponse = try await APIClient().post("/auth/register", body: RegBody(email: email, password: password, name: name))
        struct JoinBody: Encodable { let inviteCode: String }
        let join: JoinResponse = try await APIClient(token: reg.token).post(
            "/api/household/join", body: JoinBody(inviteCode: inviteCode.uppercased())
        )
        authStore.save(token: join.token, userId: reg.userId, householdId: join.householdId, inviteCode: join.inviteCode)
        model.configure(token: join.token)
        await model.syncAll()
    }

    private func finalize(resp: AuthResponse, inviteCode: String?) {
        authStore.save(token: resp.token, userId: resp.userId, householdId: resp.householdId, inviteCode: inviteCode)
        model.configure(token: resp.token)
        Task { await model.syncAll() }
    }

    // MARK: - 入力フィールド

    private var wardField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("お住まいの区")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Menu {
                Picker("区", selection: $ward) {
                    Text("選択してください").tag("")
                    ForEach(TokyoWard.all, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack {
                    Text(ward.isEmpty ? "選択してください" : ward)
                        .foregroundStyle(ward.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text("区ごとの給付金・助成制度の表示に使います。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthStore())
        .environment(AppModel())
}
