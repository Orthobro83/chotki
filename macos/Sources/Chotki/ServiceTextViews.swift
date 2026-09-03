import SwiftUI
import ChotkiCore

/// The list of everything in the book that is followed rather than kept.
///
/// Reached from the top of the Reading, above the day's own readings, because
/// that is where the app's other long texts already are. The prayers dropdown
/// is for what a rule is made of; a forty-page Liturgy is not that.
///
/// Titles and order are the book's own, so someone holding the printed copy
/// finds the same thing in the same place.
struct ServiceTextListContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ServiceTextList(model: model) { model.screen = .serviceText($0) }
    }
}

/// One service, read straight through.
struct ServiceTextViewContent: View {
    @ObservedObject var model: AppModel
    let id: String

    private var text: ServiceText? { ServiceTexts.text(id: id) }

    var body: some View {
        if let text {
            let glossary = Glossary.shared(for: model.settings.jurisdiction.tradition)
            // Scanned once across the whole service, so a word is linked where
            // it first appears rather than in every one of forty pages.
            let found = glossary.scanOnce(text.paragraphs)

            VStack(alignment: .leading, spacing: 9) {
                ForEach(Array(text.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    if isHeading(paragraph) {
                        Text(paragraph)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, index == 0 ? 0 : 8)
                    } else {
                        PrayerProse(
                            model: model, paragraphs: [paragraph],
                            size: 13, spacing: 4, matches: [found[index]]
                        )
                    }
                }
                Text(ServiceTexts.source)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 10)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("That text is not in the book.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(16)
        }
    }

    /// The book sets its banners and tone markings in capitals, and the scan
    /// keeps that, so they are told apart by shape rather than by a flag the
    /// extraction would have to invent.
    private func isHeading(_ paragraph: String) -> Bool {
        guard paragraph.count < 60 else { return false }
        let letters = paragraph.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { $0.isUppercase }
    }
}

/// The window shows the service texts as a sheet, the way it shows a rule's
/// prayers, and keeps the list-then-text step inside it.
///
/// Its own small navigation rather than the app's: the sheet is a place you
/// enter and leave, and pushing `model.screen` from inside it would fight the
/// route that opened it.
struct ServiceSheet: Identifiable {
    let openTextID: String?
    var id: String { openTextID ?? "list" }
}

struct ServiceSheetView: View {
    @ObservedObject var model: AppModel
    let openTextID: String?
    var onClose: () -> Void

    @State private var showing: String?
    @State private var started = false

    var body: some View {
        VStack(spacing: 0) {
            if let showing, let text = ServiceTexts.text(id: showing) {
                // Back goes to the list, which is the screen it came from.
                Header(title: text.title) { self.showing = nil }
                ScrollView { ServiceTextViewContent(model: model, id: showing) }
            } else {
                Header(title: "Service texts", back: onClose)
                ScrollView { ServiceTextList(model: model) { showing = $0 } }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            showing = openTextID
        }
    }
}

/// The list, told where to send a tap.
///
/// Split from `ServiceTextListContent` so the window's sheet can keep the
/// choice inside itself while the popover sets `model.screen`. Same rows, same
/// order, one list — the two surfaces differ in where a tap goes and in
/// nothing else.
struct ServiceTextList: View {
    @ObservedObject var model: AppModel
    var onChoose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("The parts of the prayer book that are followed rather than said as a rule — what happens in church, and the long devotions read through on their own.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16).padding(.bottom, 12)

            ForEach(ServiceTexts.all) { text in
                Button { onChoose(text.id) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(text.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.parchment)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Text(text.lengthDescription)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Read \(text.title)")

                Divider().overlay(Theme.lineSoft).padding(.leading, 16)
            }

            Text(ServiceTexts.source)
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .padding(.horizontal, 16).padding(.top, 12)
        }
        .padding(.vertical, 10)
    }
}
