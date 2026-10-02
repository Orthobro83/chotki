import SwiftUI

struct FatherPrompt: View {
    @ObservedObject var model: AppModel
    @State private var naming = false
    @State private var name = ""
    var body: some View {
        ZStack {
            Theme.ground.opacity(0.97)
            VStack(spacing: 22) {
                Text("Chotki is best used in cooperation with a priest or spiritual father. Have you found one yet?")
                    .font(Theme.reading(22)).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                if naming {
                    TextField("Name", text: $name).textFieldStyle(.roundedBorder).font(Theme.reading(18))
                        .accessibilityLabel("Spiritual Father's Name")
                    Button("Save") { model.update { $0.spiritualFatherName = name.trimmingCharacters(in: .whitespacesAndNewlines) } }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).buttonStyle(GoldButtonStyle())
                } else {
                    HStack(spacing: 12) {
                        Button("Yes I Have") { naming = true }.buttonStyle(GoldButtonStyle())
                        Button("Not Yet") { model.update { $0.spiritualFatherDeferredOn = model.today } }.buttonStyle(GoldButtonStyle())
                    }
                }
            }.foregroundStyle(Theme.parchment).padding(28).frame(maxWidth: 490)
        }
    }
}
