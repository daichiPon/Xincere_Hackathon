import SwiftUI
import Combine

/// S-13 マイページ。子・世帯のプロフィール、パートナー連携、ログアウトを集約する。
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var childName = ""
    @State private var birthDate = Date.now
    @State private var ward = ""
    @State private var isPreterm = false

    @State private var saving = false
    @State private var savedNote: String?

    @State private var invite: InviteInfo?
    @State private var issuingInvite = false
    @State private var showJoin = false
    @State private var joinCode = ""
    @State private var joinError: String?

    // 招待コードの残り時間表示用。
    @State private var now = Date.now
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var dirty: Bool {
        childName != model.childName
            || !Calendar.current.isDate(birthDate, inSameDayAs: model.birthDate)
            || ward != TokyoWard.normalized(model.municipality)
            || isPreterm != model.isPreterm
    }

    var body: some View {
        NavigationStack {
            Form {
                childSection
                partnerSection
                Section {
                    Button(role: .destructive) {
                        authStore.logout()
                        dismiss()
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "保存中…" : "保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!dirty || saving)
                }
            }
            .onAppear(perform: loadFromModel)
            .task { invite = await model.fetchInvite() }
            .onReceive(ticker) { now = $0 }
            .sheet(isPresented: $showJoin) { joinSheet }
        }
    }

    // MARK: - 子・世帯

    @ViewBuilder
    private var childSection: some View {
        Section {
            LabeledContent("お子さんの名前") {
                TextField("なまえ", text: $childName).multilineTextAlignment(.trailing)
            }
            DatePicker("生年月日", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
            Picker("お住まいの区", selection: $ward) {
                ForEach(TokyoWard.all, id: \.self) { Text($0).tag($0) }
            }
            Toggle("早産・低出生体重で生まれた", isOn: $isPreterm)
        } header: {
            Text("お子さん・世帯")
        } footer: {
            if let savedNote {
                Text(savedNote).foregroundStyle(Theme.sage)
            } else if dirty {
                Text("右上の「保存」で変更を確定します。")
            } else {
                Text("生年月日と区は、予防接種や給付金の時期の計算に使います。")
            }
        }
    }

    private func save() {
        Task {
            saving = true
            let err = await model.updateHousehold(
                childName: childName, birthDate: birthDate,
                municipality: ward, isPreterm: isPreterm
            )
            saving = false
            savedNote = err ?? "保存しました"
            try? await Task.sleep(for: .seconds(2))
            savedNote = nil
        }
    }

    // MARK: - パートナー連携

    private var partnerSection: some View {
        Section {
            if let invite, invite.expiresAt > now {
                VStack(spacing: 10) {
                    Text(invite.code)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(Theme.brand)
                    Text("有効期限まで \(remaining(invite.expiresAt))")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        UIPasteboard.general.string = invite.code
                    } label: {
                        Label("コードをコピー", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Button {
                Task {
                    issuingInvite = true
                    invite = await model.issueInvite()
                    issuingInvite = false
                }
            } label: {
                HStack {
                    if issuingInvite { ProgressView() }
                    Label(invite == nil ? "招待コードを発行" : "コードを再発行", systemImage: "person.badge.plus")
                }
            }
            .disabled(issuingInvite)

            Button {
                joinCode = ""; joinError = nil; showJoin = true
            } label: {
                Label("招待コードで参加する", systemImage: "person.2")
            }
        } header: {
            Text("パートナーと共有")
        } footer: {
            Text("「発行」で作ったコードをパートナーに伝え、相手のマイページで「参加する」から入力すると、同じ世帯の記録・やることを共有できます。コードは発行から10分・1回だけ有効です。")
        }
    }

    private var joinSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("招待コード（8文字）", text: $joinCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                } footer: {
                    if let joinError { Text(joinError).foregroundStyle(.red) }
                    else { Text("参加すると、今このアカウントに入っている記録はパートナーの世帯のものに切り替わります。") }
                }
                Section {
                    Button("この世帯に参加") {
                        Task {
                            let err = await joinHousehold()
                            if err == nil { showJoin = false; dismiss() }
                            else { joinError = err }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(joinCode.count != 8)
                }
            }
            .navigationTitle("招待コードで参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("やめる") { showJoin = false } }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func loadFromModel() {
        childName = model.childName
        birthDate = model.birthDate
        ward = TokyoWard.normalized(model.municipality)
        isPreterm = model.isPreterm
    }

    private func remaining(_ date: Date) -> String {
        let s = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func joinHousehold() async -> String? {
        guard let token = authStore.token else { return "ログインが必要です" }
        do {
            struct Body: Encodable { let inviteCode: String }
            let resp: JoinResponse = try await APIClient(token: token).post(
                "/api/household/join", body: Body(inviteCode: joinCode.uppercased())
            )
            authStore.updateHousehold(token: resp.token, householdId: resp.householdId)
            model.configure(token: resp.token)
            await model.syncAll()
            return nil
        } catch let e as APIError {
            return e.errorDescription
        } catch {
            return error.localizedDescription
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppModel())
        .environment(AuthStore())
}
