import SwiftUI

/// S-07 計測入力。身長・体重・頭囲を入力する。
struct MeasurementInputView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var height = 63.4
    @State private var weight = 6.9
    @State private var head = 41.6
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("計測日") {
                    DatePicker("計測日", selection: $date, in: ...Date.now, displayedComponents: .date)
                }
                stepperRow(title: "身長", value: $height, range: 40...110, step: 0.1, unit: "cm")
                stepperRow(title: "体重", value: $weight, range: 2...25, step: 0.1, unit: "kg")
                stepperRow(title: "頭囲", value: $head, range: 30...55, step: 0.1, unit: "cm")
            }
            .navigationTitle("計測を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        model.measurements.append(
                            Measurement(ageMonths: model.ageMonths, date: date,
                                        heightCm: height, weightKg: weight, headCm: head)
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private func stepperRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        Section(title) {
            Stepper(value: value, in: range, step: step) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(String(format: "%.1f %@", value.wrappedValue, unit))
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.brand)
                }
            }
        }
    }
}

#Preview {
    MeasurementInputView()
        .environment(AppModel())
}
