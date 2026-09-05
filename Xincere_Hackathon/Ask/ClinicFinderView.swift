import SwiftUI

/// S-15 医療機関検索（簡易リスト版）。
/// 診療時間ベースの「今開いている可能性」を明示し、実態との乖離を注記する。
struct ClinicFinderView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "すべて"
        case pediatrics = "小児科"
        case emergency = "夜間・休日"
        case vaccine = "予防接種"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all

    private let clinics: [Clinic] = [
        Clinic(name: "しぶや小児科クリニック", tags: [.pediatrics, .vaccine], distance: "0.4km", hours: "9:00–18:00", likelyOpen: true, phone: "0300000001"),
        Clinic(name: "渋谷こどもの森医院", tags: [.pediatrics], distance: "0.9km", hours: "9:00–12:30 / 15:00–18:00", likelyOpen: false, phone: "0300000002"),
        Clinic(name: "区西部 夜間休日診療所", tags: [.emergency, .pediatrics], distance: "1.6km", hours: "20:00–翌6:00", likelyOpen: true, phone: "0300000003"),
        Clinic(name: "たまがわ小児クリニック", tags: [.pediatrics, .vaccine], distance: "2.1km", hours: "9:30–17:30", likelyOpen: true, phone: "0300000004"),
    ]

    private var filtered: [Clinic] {
        switch filter {
        case .all: clinics
        case .pediatrics: clinics.filter { $0.tags.contains(.pediatrics) }
        case .emergency: clinics.filter { $0.tags.contains(.emergency) }
        case .vaccine: clinics.filter { $0.tags.contains(.vaccine) }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("絞り込み", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                ForEach(filtered) { clinic in
                    ClinicRow(clinic: clinic)
                }

                Text("診療時間は公表情報に基づく目安です。実際の受け入れ可否は各医療機関にご確認ください。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .padding(16)
        }
        .background(Theme.screenBackground)
        .navigationTitle("医療機関を探す")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ClinicRow: View {
    let clinic: Clinic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(clinic.name).font(.headline)
                Spacer()
                Text(clinic.distance).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(clinic.likelyOpen ? Theme.sage : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(clinic.likelyOpen ? "今開いている可能性" : "時間外の可能性")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(clinic.likelyOpen ? Theme.sage : .secondary)
                Text("・\(clinic.hours)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                ForEach(clinic.tags) { tag in
                    Text(tag.label)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.brandSoft, in: Capsule())
                        .foregroundStyle(Theme.brand)
                }
                Spacer()
                Link(destination: URL(string: "tel://\(clinic.phone)")!) {
                    Label("電話", systemImage: "phone.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.brand, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        }
        .cardStyle()
    }
}

struct Clinic: Identifiable {
    enum Tag: Identifiable {
        case pediatrics, emergency, vaccine
        var id: String { label }
        var label: String {
            switch self { case .pediatrics: "小児科"; case .emergency: "夜間・休日"; case .vaccine: "予防接種" }
        }
    }
    let id = UUID()
    var name: String
    var tags: [Tag]
    var distance: String
    var hours: String
    var likelyOpen: Bool
    var phone: String
}

#Preview {
    NavigationStack { ClinicFinderView() }
}
