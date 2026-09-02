import SwiftUI
import UniformTypeIdentifiers
import ChotkiCore

/// The seven questions, Sunday through Saturday, and somewhere to answer them.
///
/// Not a tab. iPhone shows five before folding the rest into a "More" list, and
/// that list is a worse home for anything than a considered arrangement — so
/// this is reached the way the glossary and the Psalter are: from the rule that
/// names it on the day, and from Settings for browsing.
struct ReflectionsView: View {
    @State var model: Model
    /// The weekday to open on, from the rule that sent us here. nil starts at
    /// the top.
    var openAt: Weekday?

    @State private var reading: Weekday?
    @State private var explaining = false
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if explaining { ReflectionExplainer { withAnimation { explaining = false } } }
                    TakeOnRow(model: model)
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        DayBlock(model: model, weekday: weekday) { reading = weekday }
                            .id(weekday)
                    }
                    Colophon()
                    FileRow(onExport: { exporting = true }, onImport: { importing = true })
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            // A long form with seven text fields and no way to put the keyboard
            // away except by saving. Dragging is what anyone tries first.
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard let openAt else { return }
                // After the first layout, not during it: a LazyVStack has not
                // built the later days yet when `onAppear` fires, so scrolling
                // to Saturday in the same turn finds nothing to scroll to.
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.35)) {
                        scroller.scrollTo(openAt, anchor: .top)
                    }
                }
            }
        }
        .background(Chotki.ground)
        .navigationTitle("Reflections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeOut(duration: 0.28)) { explaining.toggle() }
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("What this is for")
            }
        }
        // A sheet rather than the Mac's panel with arrows either side. There is
        // no room beside a full-width sheet on a phone, so the dates are a list
        // you tap into instead.
        .sheet(item: $reading) { weekday in
            PastEntriesView(model: model, weekday: weekday)
        }
        .fileExporter(
            isPresented: $exporting,
            document: JournalFile(data: (try? model.exportReflectionsJSON()) ?? Data()),
            contentType: .json,
            defaultFilename: "reflections-\(model.today.iso)"
        ) { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            // A file from the picker lives outside the sandbox until asked for.
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                model.trouble = "That file could not be opened."
                return
            }
            model.importReflectionsJSON(data)
        }
    }
}

/// The one control that puts Reflections on the rule.
///
/// The explainer's last line tells the reader to click a button of this name,
/// and for a while that button existed only on macOS — so on a phone the text
/// named something that was not there. Both halves come from
/// `Reflection.addAsRuleLabel`, so they cannot drift apart again, and
/// `PortParityTests` now fails if a platform lacks it.
///
/// It opens the editor pre-filled rather than adding straight away, because
/// that is how everything is taken on here: how often is a decision, and asking
/// afterwards meant finding the rule on the day and opening the pencil.
private struct TakeOnRow: View {
    @State var model: Model
    @Environment(\.pushRoute) private var pushRoute

    var body: some View {
        HStack {
            if model.hasReflectionsOnRule {
                // Stated as a fact, not as praise and not as a prompt to do
                // more. There is nothing left to press.
                Text("On your rule")
                    .font(.caption)
                    .foregroundStyle(Chotki.faint)
            } else {
                Button(Reflection.addAsRuleLabel) {
                    guard let template = model.reflectionTemplate else { return }
                    pushRoute(.editor(ruleID: nil, startingFrom: model.ruleFrom(template)))
                }
                .font(.callout)
                .foregroundStyle(Chotki.gold)
            }
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: one weekday

private struct DayBlock: View {
    @State var model: Model
    let weekday: Weekday
    let openPast: () -> Void

    @State private var draft = ""
    @State private var editing = false
    @State private var confirming = false
    @FocusState private var writing: Bool

    private var reflection: Reflection { model.reflection(for: weekday) }
    private var past: Int { model.reflectionSeries(for: weekday).count }
    private var isToday: Bool { model.today.weekday == weekday }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if editing {
                QuestionEditor(question: reflection.question) { question in
                    if let question { model.rewriteReflection(weekday, to: question) }
                    editing = false
                }
            } else {
                question
                answer
            }
        }
        .padding(.bottom, 26)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Format.weekdayName(weekday).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Chotki.gold)
            if isToday {
                Text("today")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Chotki.ground)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Chotki.gold, in: RoundedRectangle(cornerRadius: 3))
            }
            Spacer(minLength: 8)
            Button(action: openPast) {
                Text(past == 0 ? "no past entries" : (past == 1 ? "1 past entry" : "\(past) past entries"))
                    .font(.caption)
                    .foregroundStyle(past == 0 ? Chotki.faint : Chotki.muted)
            }
            .disabled(past == 0)
            .accessibilityLabel("Past entries for \(Format.weekdayName(weekday))")
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Chotki.line).frame(height: 1) }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(reflection.title)
                    .font(Chotki.reading(19, relativeTo: .title3))
                    .foregroundStyle(Chotki.parchment)
                Spacer(minLength: 8)
                Button("Edit") { editing = true }
                    .font(.caption)
                    .foregroundStyle(Chotki.muted)
            }
            // Neither half is labelled. The task lines say "At the end of the
            // day…" themselves, and a word in the margin of the notice only
            // named what the whole section is already called.
            Text(reflection.notice)
                .font(Chotki.reading(15))
                .foregroundStyle(Chotki.parchmentDim)
                .fixedSize(horizontal: false, vertical: true)
            Text(reflection.task)
                .font(Chotki.reading(15))
                .foregroundStyle(Chotki.parchment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var answer: some View {
        if let written = model.answer(for: weekday) {
            VStack(alignment: .leading, spacing: 6) {
                Text(written.text)
                    .font(Chotki.reading(15))
                    .foregroundStyle(Chotki.parchment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 8))
                Text("Written \(Format.dateWithYear(written.date)).")
                    .font(.caption)
                    .foregroundStyle(Chotki.faint)
            }
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $draft)
                    .font(Chotki.reading(15))
                    .foregroundStyle(Chotki.parchment)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 96)
                    .padding(8)
                    .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topLeading) {
                        if draft.isEmpty {
                            Text(isToday ? "Write today’s answer…" : "Nothing written for this day yet.")
                                .font(Chotki.reading(15).italic())
                                .foregroundStyle(Chotki.faint)
                                .padding(.horizontal, 13).padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .focused($writing)
                    // SwiftUI lifts a focused field clear of the keyboard on its
                    // own, but only when it can see how far — a fixed-height
                    // editor deep in a LazyVStack is exactly where that fails.
                    // Scrolling to this block when it takes focus does what the
                    // automatic behaviour cannot.
                    .id("editor-\(weekday.rawValue)")

                HStack {
                    Button("Save") { confirming = true }
                        .font(.callout)
                        .foregroundStyle(ready ? Chotki.gold : Chotki.faint)
                        .disabled(!ready)
                    Spacer()
                    if let last = model.reflectionSeries(for: weekday).entries.first {
                        Text("last written \(Format.dateWithYear(last.date))")
                            .font(.caption)
                            .foregroundStyle(Chotki.faint)
                    }
                }
            }
            .padding(.top, 12)
            .alert("Save this answer?", isPresented: $confirming) {
                Button("Save") {
                    model.saveReflection(weekday, text: draft)
                    draft = ""
                    writing = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Once saved it is kept as written and cannot be changed.")
            }
        }
    }

    private var ready: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: rewriting a question

private struct QuestionEditor: View {
    let question: ReflectionQuestion
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
        VStack(alignment: .leading, spacing: 10) {
            field("Title", text: $title, minHeight: 34)
            field("Notice", text: $notice, minHeight: 90)
            field("Then", text: $task, minHeight: 70)

            Text("""
                This changes the question from today onward. Every answer already \
                written keeps the question it was written against, and stays readable.
                """)
                .font(.caption)
                .foregroundStyle(Chotki.muted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 18) {
                Button("Save") {
                    done(ReflectionQuestion(title: title, notice: notice, task: task))
                }
                .font(.callout)
                .foregroundStyle(Chotki.gold)
                Button("Cancel") { done(nil) }
                    .font(.callout)
                    .foregroundStyle(Chotki.muted)
            }
        }
        .padding(.top, 12)
    }

    private func field(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Chotki.faint)
            TextEditor(text: text)
                .font(Chotki.reading(15))
                .foregroundStyle(Chotki.parchment)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: reading back

/// The dates a weekday holds, and one of them opened.
///
/// A list rather than the Mac's arrows either side of a panel: at this width
/// there is nowhere for chevrons to go, and the shape of a year is visible at a
/// glance in a list in a way it never is behind a pair of arrows.
private struct PastEntriesView: View {
    @State var model: Model
    let weekday: Weekday
    @Environment(\.dismiss) private var dismiss
    @State private var open: ReflectionEntry?

    private var entries: [ReflectionEntry] {
        model.reflectionSeries(for: weekday).entries
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    Button { open = entry } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Format.dateWithYear(entry.date))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Chotki.parchment)
                            Text(entry.text)
                                .font(Chotki.reading(14))
                                .foregroundStyle(Chotki.faint)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowBackground(Chotki.ground)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Chotki.ground)
            .navigationTitle(Format.weekdayName(weekday))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(item: $open) { entry in
                PastEntryView(entry: entry)
            }
        }
    }
}

/// One answer, with the question **as it stood when it was written** — which is
/// what the copy on every entry is for. Reading an answer against a question it
/// never answered would be worse than showing no question at all.
private struct PastEntryView: View {
    let entry: ReflectionEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.question.title)
                    .font(Chotki.reading(19, relativeTo: .title3))
                    .foregroundStyle(Chotki.parchment)
                Text(entry.question.notice)
                    .font(Chotki.reading(14))
                    .foregroundStyle(Chotki.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.question.task)
                    .font(Chotki.reading(14))
                    .foregroundStyle(Chotki.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle().fill(Chotki.line).frame(height: 1).padding(.vertical, 4)

                Text(entry.text)
                    .font(Chotki.reading(16))
                    .foregroundStyle(Chotki.parchment)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
        .background(Chotki.ground)
        .navigationTitle(Format.dateWithYear(entry.date))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: the rest of the screen

/// What the section is for. Ryan's words, from core.
private struct ReflectionExplainer: View {
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(Reflection.explainer.enumerated()), id: \.offset) { _, paragraph in
                Text(attributed(paragraph))
                    .font(Chotki.reading(14))
                    .foregroundStyle(Chotki.parchmentDim)
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(Chotki.gold)
            }
            Button("Close", action: close)
                .font(.caption)
                .foregroundStyle(Chotki.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Chotki.panel, in: RoundedRectangle(cornerRadius: 10))
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private func attributed(_ paragraph: WelcomeParagraph) -> AttributedString {
        var whole = AttributedString()
        for span in paragraph.spans {
            var piece = AttributedString(span.text)
            if let url = span.url, let link = URL(string: url) {
                piece.link = link
                piece.foregroundColor = Chotki.gold
                piece.underlineStyle = .single
            }
            whole.append(piece)
        }
        return whole
    }
}

/// The Brotherhood's closing text, verbatim. Kept because it names who to ask —
/// a priest, confession — which is what the app is meant to do instead of
/// instructing. It is quoted, not the app's own voice, and is not reworded.
private struct Colophon: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Reflection.closingText, id: \.self) { paragraph in
                Text(paragraph)
                    .font(Chotki.reading(14))
                    .foregroundStyle(Chotki.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 18)
        .overlay(alignment: .top) { Rectangle().fill(Chotki.line).frame(height: 1) }
    }
}

private struct FileRow: View {
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kept in your own record, with everything else.")
                .font(.caption)
                .foregroundStyle(Chotki.faint)
            HStack(spacing: 20) {
                Button("Export journal", action: onExport)
                Button("Import journal", action: onImport)
            }
            .font(.callout)
            .foregroundStyle(Chotki.gold)
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The journal as a file the picker can hand out. Plain JSON, the same shape
/// macOS writes, so a journal moves between them.
private struct JournalFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension Weekday: @retroactive Identifiable {
    public var id: Int { rawValue }
}
