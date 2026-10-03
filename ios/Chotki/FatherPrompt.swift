import SwiftUI
import ChotkiCore

/// Asked thirty days after the welcome, and again thirty days after "Not yet".
/// Once a name is stored it is not asked again. The name is changed later in Settings.
struct FatherPrompt: View {
    @Bindable var model: Model
    @State private var naming = false
    @State private var name = ""

    var body: some View {
        ZStack {
            Chotki.ground.opacity(0.94)
            VStack(spacing: 22) {
                Text("Chotki is best used in cooperation with a priest or spiritual father. Have you found one yet?")
                    .font(Chotki.reading(20))
                    .foregroundStyle(Chotki.parchment)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if naming {
                    TextField("Name", text: $name)
                        .font(Chotki.reading(17))
                        .foregroundStyle(Chotki.parchment)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel("Spiritual father's name")
                    promptButton("Save", enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        model.update { $0.spiritualFatherName = trimmed }
                    }
                } else {
                    HStack(spacing: 10) {
                        promptButton("Yes I have") { naming = true }
                        promptButton("Not yet") {
                            let today = model.today
                            model.update { $0.spiritualFatherDeferredOn = today }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 490)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spiritual father")
    }

    private func promptButton(_ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Chotki.ground)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Chotki.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(label)
    }
}
