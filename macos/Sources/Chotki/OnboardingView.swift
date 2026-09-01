import SwiftUI
import ChotkiCore

/// First run, once and never again.
///
/// This replaced a screen that suggested three rules and let you tick them
/// there and then. That screen and this one both said "start small" in
/// different words, and two screens saying the same thing in different words is
/// worse than one — so the suggestions went and the Library does that job,
/// which is where someone ends up anyway.
///
/// The words are in `Welcome`, in core, so this and the Android screen cannot
/// drift apart.
struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                RopeMark(size: 64)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)

                Text(Welcome.title)
                    .font(Theme.reading(21))
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity, alignment: .center)

                ForEach(Array(Welcome.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    Paragraph(paragraph)
                }

                Button {
                    model.update { $0.hasCompletedFirstRun = true }
                    model.notice = nil
                } label: {
                    Text(Welcome.beginLabel)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 22).padding(.vertical, 6)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.goldDim))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
    }
}

/// One paragraph, with its links live.
///
/// Built as an `AttributedString` from the spans rather than parsed out of
/// marked-up text: core hands over where the links are, so nothing here has to
/// work it out.
private struct Paragraph: View {
    let paragraph: WelcomeParagraph

    init(_ paragraph: WelcomeParagraph) { self.paragraph = paragraph }

    private var text: AttributedString {
        var whole = AttributedString()
        for span in paragraph.spans {
            var piece = AttributedString(span.text)
            if let url = span.url, let link = URL(string: url) {
                piece.link = link
                piece.foregroundColor = Theme.gold
                piece.underlineStyle = .single
            }
            whole.append(piece)
        }
        return whole
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            if paragraph.isAside {
                Rectangle().fill(Theme.line).frame(width: 2)
            }
            Text(text)
                .font(Theme.reading(paragraph.isAside ? 11.5 : 12.5))
                .foregroundStyle(paragraph.isAside ? Theme.faint : Theme.parchmentDim)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .tint(Theme.gold)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
