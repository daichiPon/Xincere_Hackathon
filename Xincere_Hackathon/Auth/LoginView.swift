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
    @State private var birthDate = Date.now
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header

                    Picker("モード", selection: $mode) {
                        ForEach(AuthMode.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 14) {
                        inputField("メールアドレス", text: $email, keyboard: .emailAddress)
                        inputField(mode == .login ? "パスワード" : "パスワード（6文字以上）", text: $password, isSecure: true)

                        if mode == .register || mode == .join {
                            inputField("あなたの名前", text: $name)
                        }
                        if mode == .register {
                            wardField
                            birthDateField
                        }
                        if mode == .join {
                            inputField("招待コード（8文字）", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote).foregroundStyle(.red)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }

                    Button(action: submit) {
                        ZStack {
                            if isLoading { ProgressView().tint(.white) }
                            else { Text(mode.label).font(.headline).foregroundStyle(.white) }
                        }
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isLoading || !formValid)

                    if mode == .join {
                        Text("パートナーがマイページで発行した招待コード（有効10分）を入力すると、同じ世帯のデータを共有できます。")
                            .font(.caption).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.and.child.holdinghands")
                .font(.system(size: 56)).foregroundStyle(Theme.brand)
            Text("Xincere").font(.largeTitle.bold())
            Text("家族の育児記録を、ひとつに")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top, 32)
    }

    // MARK: - バリデーション

    private var formValid: Bool {
        switch mode {
        case .login:    !email.isEmpty && password.count >= 6
        case .register: !email.isEmpty && password.count >= 6 && !name.isEmpty && !ward.isEmpty
        case .join:     !name.isEmpty && !email.isEmpty && password.count >= 6 && inviteCode.count == 8
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
        finalize(resp)
    }

    private func doRegister() async throws {
        struct Body: Encodable {
            let email: String; let password: String; let name: String
            let municipality: String; let birthDateMs: Int
        }
        let resp: AuthResponse = try await APIClient().post("/auth/register", body: Body(
            email: email, password: password, name: name,
            municipality: ward,
            birthDateMs: Int(birthDate.timeIntervalSince1970 * 1000)
        ))
        model.municipality = ward
        model.birthDate = birthDate
        finalize(resp)
    }

    private func doJoin() async throws {
        struct RegBody: Encodable { let email: String; let password: String; let name: String }
        let reg: AuthResponse = try await APIClient().post("/auth/register", body: RegBody(email: email, password: password, name: name))
        struct JoinBody: Encodable { let inviteCode: String }
        let join: JoinResponse = try await APIClient(token: reg.token).post(
            "/api/household/join", body: JoinBody(inviteCode: inviteCode.uppercased())
        )
        authStore.save(token: reg.token, userId: reg.userId, householdId: reg.householdId)
        authStore.updateHousehold(token: join.token, householdId: join.householdId)
        model.configure(token: join.token)
        await model.syncAll()
    }

    private func finalize(_ resp: AuthResponse) {
        authStore.save(token: resp.token, userId: resp.userId, householdId: resp.householdId)
        model.configure(token: resp.token)
        Task { await model.syncAll() }
    }

    // MARK: - 入力フィールド

    private var wardField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("お住まいの区")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
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
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            Text("区ごとの給付金・助成制度の表示に使います。あとからマイページで変更できます。")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var birthDateField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("お子さんの生年月日")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            DatePicker("生年月日", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text("予防接種や手続きの時期の計算に使います。出産予定日でも登録でき、あとから直せます。")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
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
