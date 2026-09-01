import SwiftUI
import AppKit
import ChotkiCore

/// Scroll chrome only. Content is `ReflectionsViewContent` so it can be
/// rendered directly — ImageRenderer draws no ScrollView contents, which is how
/// an empty screen once got signed off here.
struct ReflectionsView: View {
    @ObservedObject var model: AppModel
    @State private var reading: Weekday?
    @State private var explaining = false

    /// `initialReading` and `initialExplaining` exist for the render harness.
    /// Both panels are raised by `@State`, so nothing outside this view can open
    /// them — and a screen that cannot be drawn is a screen that gets signed off
    /// unseen.
    init(model: AppModel, initialReading: Weekday? = nil, initialExplaining: Bool = false) {
        self.model = model
        _reading = State(initialValue: initialReading)
        _explaining = State(initialValue: initialExplaining)
    }

    var body: some View {
        ScrollView {
            ReflectionsViewContent(
                model: model, reading: $reading, explaining: $explaining)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackgroundHidden()
        // `.overlay` rather than a `ZStack`, deliberately. A ZStack takes its
        // size from its children, so a panel appearing beside a ScrollView made
        // the whole thing report the ScrollView's *content* height — which
        // stretched the window to the height of the screen. An overlay is laid
        // out inside its host and can never resize it.
        .overlay(alignment: .top) {
            // Comes down over the section rather than pushing it apart, so
            // nothing underneath moves and the place someone was reading stays
            // where they left it.
            if explaining {
                ReflectionExplainer { close() }
                    // Same column as the content beneath it. Centred, it sat
                    // 50 points to the right of everything it explains.
                    .frame(maxWidth: 640, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // Clears the header rather than covering it. The last line
                    // of the text names the button beside the help mark, and
                    // hiding the thing you have just been told to press is a
                    // poor way to explain anything.
                    .padding(.top, 42)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let weekday = reading {
                ReflectionOverlay(model: model, weekday: weekday) { reading = nil }
                    .transition(.opacity)
            }
        }
        .clipped()
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.22)) { explaining = false }
    }
}

/// The seven, Sunday through Saturday, and what closes the week.
struct ReflectionsViewContent: View {
    @ObservedObject var model: AppModel
    var reading: Binding<Weekday?>?
    var explaining: Binding<Bool>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(model: model, explaining: explaining)
            ForEach(Weekday.allCases, id: \.self) { weekday in
                DayBlock(model: model, weekday: weekday, reading: reading)
            }
            Colophon()
            FileBar(model: model)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 30)
    }
}

/// The section's own header: what it is called, how to find out what it is for,
/// and the one control that puts it on the rule.
private struct SectionHeader: View {
    @ObservedObject var model: AppModel
    var explaining: Binding<Bool>?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("Reflections")
                .font(Theme.reading(17))
                .foregroundStyle(Theme.parchment)

            Button {
                withAnimation(.easeOut(duration: 0.28)) {
                    explaining?.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        explaining?.wrappedValue == true ? Theme.gold : Theme.muted)
            }
            .buttonStyle(.plain)
            .help("What this is for")

            if model.hasReflectionsOnRule {
                // Stated as a fact, not as praise and not as a prompt to do
                // more. There is nothing left to press.
                Text("On your rule")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).stroke(Theme.lineSoft, lineWidth: 1)
                    }
            } else {
                Button(Reflection.addAsRuleLabel) { model.addReflectionsToRule() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5).stroke(Theme.goldDim, lineWidth: 1)
                    }
                    .help("Puts one question a day on your rule, each on its own weekday")
            }
            Spacer(minLength: 8)
        }
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

/// What the section is for. Ryan's words, from `core`.
private struct ReflectionExplainer: View {
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(Reflection.explainer.enumerated()), id: \.offset) { _, paragraph in
                Text(attributed(paragraph))
                    .font(Theme.reading(12.5))
                    .foregroundStyle(Theme.parchmentDim)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(Theme.gold)
            }
            Button("Close", action: close)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
        .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
    }

    private func attributed(_ paragraph: WelcomeParagraph) -> AttributedString {
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
}

// MARK: one weekday

private struct DayBlock: View {
    @ObservedObject var model: AppModel
    let weekday: Weekday
    var reading: Binding<Weekday?>?

    @State private var draft = ""
    @State private var editing = false
    @State private var confirming = false

    private var reflection: Reflection { model.reflection(for: weekday) }
    private var series: ReflectionSeries { model.reflectionSeries(for: weekday) }
    private var isToday: Bool { CalendarDate(Date(), in: .current).weekday == weekday }
    private var answered: Bool { model.hasAnsweredToday(weekday) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if editing {
                ReflectionEditor(question: reflection.question) { question in
                    if let question { model.rewriteReflection(weekday, to: question) }
                    editing = false
                }
            } else {
                question
                answer
            }
        }
        .padding(.bottom, 22)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Format.weekdayName(weekday).uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.gold)
            if isToday {
                Text("today")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.ground)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 3))
            }
            Spacer(minLength: 8)
            past
        }
        .padding(.bottom, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    @ViewBuilder private var past: some View {
        let count = series.count
        Button { reading?.wrappedValue = weekday } label: {
            Text(count == 0
                 ? "no past entries"
                 : (count == 1 ? "1 past entry" : "\(count) past entries"))
                .font(.system(size: 11))
                .foregroundStyle(count == 0 ? Theme.faint : Theme.muted)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(count == 0 ? Theme.lineSoft : Theme.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reflection.title)
                    .font(Theme.reading(15))
                    .foregroundStyle(Theme.parchment)
                Spacer(minLength: 8)
                Button("Edit this reflection") { editing = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            // Neither half is labelled. The task lines say "At the end of the
            // day…" themselves, and a word in the margin of the notice only
            // named what the whole section is already called. The two are told
            // apart by weight, which is enough.
            QuestionLine(reflection.notice, colour: Theme.parchmentDim)
            QuestionLine(reflection.task, colour: Theme.parchment)
        }
        .padding(.top, 11)
    }

    @ViewBuilder private var answer: some View {
        if answered, let written = series.entries.first(where: {
            $0.date == model.dateOfCurrentWeek(weekday)
        }) {
            // Written and locked. Shown, not offered for editing.
            VStack(alignment: .leading, spacing: 5) {
                Text(written.text)
                    .font(Theme.reading(13))
                    .foregroundStyle(Theme.parchment)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                Text("Written \(Format.dateWithYear(written.date)).")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
            }
            .padding(.top, 10)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                TextEditor(text: $draft)
                    .font(Theme.reading(13))
                    .foregroundStyle(Theme.parchment)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 66)
                    .padding(7)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .topLeading) {
                        // TextEditor has no placeholder of its own, and an
                        // unlabelled empty box does not read as somewhere to
                        // write.
                        if draft.isEmpty {
                            Text(isToday ? "Write today's answer…" : "Nothing written for this day yet.")
                                .font(Theme.reading(13).italic())
                                .foregroundStyle(Theme.faint)
                                .padding(.horizontal, 12).padding(.vertical, 15)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6).stroke(Theme.lineSoft, lineWidth: 1)
                    }
                let ready = !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                HStack(spacing: 12) {
                    Button("Save") { confirming = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(ready ? Theme.gold : Theme.faint)
                        .padding(.horizontal, 12).padding(.vertical, 3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(ready ? Theme.goldDim : Theme.lineSoft, lineWidth: 1)
                        }
                        .disabled(!ready)
                    Spacer(minLength: 8)
                    if let last = series.entries.first {
                        Text("last written \(Format.dateWithYear(last.date))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.faint)
                    }
                }
            }
            .padding(.top, 10)
            // The guard sits at the moment of the action rather than as a
            // standing warning under an empty box, which would only nag.
            .alert("Save this answer?", isPresented: $confirming) {
                Button("Save") {
                    model.saveReflection(weekday, text: draft)
                    draft = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Once saved it is kept as written and cannot be changed.")
            }
        }
    }
}

/// One half of the question. Unlabelled — see the note where these are used.
private struct QuestionLine: View {
    let text: String
    let colour: Color

    init(_ text: String, colour: Color) {
        self.text = text
        self.colour = colour
    }

    var body: some View {
        Text(text)
            .font(Theme.reading(13))
            .foregroundStyle(colour)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: rewriting a question

private struct ReflectionEditor: View {
    let question: ReflectionQuestion
    /// nil on cancel.
    let done: (ReflectionQuestion?) -> Void

    @State private var title: String
    @State private var notice: String
    @State private var task: String

    init(question: ReflectionQuestion, done: @escaping (ReflectionQuestion?) -> Void) {
        self.question = question
        self.done = done
        _title = State(initialValue: question.title)
        _notice = State(initialValue: question.notice)
        _task = State(initialValue: question.task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            field("Title", text: $title, lines: 1)
            field("Notice", text: $notice, lines: 3)
            field("Then", text: $task, lines: 2)

            Text("""
                This changes the question from today onward. Every answer already \
                written keeps the question it was written against, and stays readable.
                """)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 62)

            HStack(spacing: 12) {
                Button("Save reflection") {
                    done(ReflectionQuestion(title: title, notice: notice, task: task))
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold)
                .padding(.horizontal, 12).padding(.vertical, 3)
                .overlay { RoundedRectangle(cornerRadius: 5).stroke(Theme.goldDim, lineWidth: 1) }
                Button("Cancel") { done(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.leading, 62)
        }
        .padding(.top, 11)
    }

    private func field(_ label: String, text: Binding<String>, lines: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .frame(width: 52, alignment: .trailing)
                .padding(.top, 6)
            TextEditor(text: text)
                .font(Theme.reading(13))
                .foregroundStyle(Theme.parchment)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(lines) * 17 + 12)
                .padding(6)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(Theme.lineSoft, lineWidth: 1) }
        }
    }
}

// MARK: what closes the week

/// The Brotherhood's closing text, verbatim.
///
/// This is the one piece of fixed copy in the app that tells the reader to do
/// something. It is kept because it names who to ask — a priest, confession —
/// which is what `design.md` says the app should do instead of instructing. It
/// is quoted, not the app's own voice, and is not reworded.
private struct Colophon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Reflection.closingText, id: \.self) { paragraph in
                Text(paragraph)
                    .font(Theme.reading(12.5))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1).padding(.top, -8)
        }
    }
}

private struct FileBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Text("Kept in your own record, with everything else, and in the daily backup.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            plain("Export journal") { export() }
            plain("Import journal") { load() }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.lineSoft).frame(height: 1).padding(.top, -2)
        }
    }

    private func plain(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Theme.parchmentDim)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(Theme.line, lineWidth: 1) }
    }

    private func export() {
        guard let data = try? model.exportReflectionsJSON() else {
            model.notice = "The journal could not be written out."
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "reflections-\(CalendarDate(Date(), in: .current).iso).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            model.notice = "Journal written to \(url.lastPathComponent)."
        } catch {
            model.notice = "The journal could not be written to that place."
        }
    }

    private func load() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        model.importReflectionsJSON(data)
    }
}

/// What the popover shows when something asks for Reflections.
///
/// The section is window-only: at 400 points there is no room for seven
/// questions, a text field each, and a journal, and the popover's job is the
/// day's rule. But the way through from a rule row has to land somewhere on
/// both surfaces — a control that works in the window and does nothing in the
/// popover is a mistake this app has made twice already, with the navigation
/// buttons and again with the marks.
struct ReflectionsElsewhere: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Format.weekdayName(model.today.weekday))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.gold)

            Text(model.reflection(for: model.today.weekday).title)
                .font(Theme.reading(16))
                .foregroundStyle(Theme.parchment)

            Text(model.reflection(for: model.today.weekday).notice)
                .font(Theme.reading(12.5))
                .foregroundStyle(Theme.parchmentDim)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(model.reflection(for: model.today.weekday).task)
                .font(Theme.reading(12.5))
                .foregroundStyle(Theme.parchment)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.lineSoft).padding(.vertical, 2)

            Text("Answers are written in the window, where the week and everything already written fit.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open the window") {
                model.openMainWindow?()
                model.screen = .reflections
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(Theme.goldDim, lineWidth: 1) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
