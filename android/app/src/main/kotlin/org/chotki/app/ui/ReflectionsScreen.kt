package org.chotki.app.ui

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.chotki.app.AppState
import org.chotki.core.Format
import org.chotki.core.Weekday
import org.chotki.core.reflections.Reflection
import org.chotki.core.reflections.ReflectionEntry
import org.chotki.core.reflections.ReflectionQuestion
import org.chotki.core.reflections.addAsRuleLabel
import org.chotki.core.reflections.bundled
import org.chotki.core.reflections.closingText
import org.chotki.core.reflections.explainer

/**
 * The seven questions, Sunday through Saturday, and somewhere to answer them.
 *
 * Not a seventh item in the bar — six is already what it carries. Reached the
 * way the Psalter is: from the rule that names it on the day, and from Settings
 * for browsing, so it is findable before that rule is taken on.
 *
 * [openAt] is the day to land on. Tapping the way through from Tuesday's rule
 * should land on Tuesday's question rather than at the top of a seven-day
 * scroll.
 */
@Composable
fun ReflectionsScreen(
    state: AppState,
    openAt: Weekday? = null,
    modifier: Modifier = Modifier,
    onTakeOn: () -> Unit = {},
) {
    val list = rememberLazyListState()
    var explaining by remember { mutableStateOf(false) }
    var reading by remember { mutableStateOf<Weekday?>(null) }
    val context = LocalContext.current

    val export = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching {
            context.contentResolver.openOutputStream(uri)?.use {
                it.write(state.exportReflectionsJson().toByteArray())
            }
        }.onFailure { state.notice = "The journal could not be written to that place." }
            .onSuccess { state.notice = "Journal written." }
    }

    val import = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val text = runCatching {
            context.contentResolver.openInputStream(uri)?.bufferedReader()?.readText()
        }.getOrNull()
        if (text == null) state.notice = "That file could not be opened."
        else state.importReflectionsJson(text)
    }

    // Deferred rather than done in composition: a LazyColumn has not built the
    // later days on the first pass, so scrolling to Saturday in the same frame
    // finds nothing to scroll to.
    LaunchedEffect(openAt) {
        val weekday = openAt ?: return@LaunchedEffect
        list.animateScrollToItem(Weekday.entries.indexOf(weekday) + 1)
    }

    LazyColumn(
        state = list,
        // The whole point of the manifest's adjustResize: the list shortens by
        // the height of the keyboard instead of being covered by it.
        modifier = modifier.fillMaxWidth().background(Chotki.ground).imePadding(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(
            start = 18.dp, end = 18.dp, bottom = 40.dp,
        ),
    ) {
        item("head") {
            SectionHead(
                state = state,
                explaining = explaining,
                onToggleExplainer = { explaining = !explaining },
                onTakeOn = onTakeOn,
            )
        }
        items(Weekday.entries.toList(), key = { it.number }) { weekday ->
            DayBlock(state, weekday) { reading = weekday }
        }
        item("colophon") { Colophon() }
        item("files") {
            FileRow(
                onExport = { export.launch("reflections-${state.today.iso}.json") },
                onImport = { import.launch(arrayOf("application/json", "*/*")) },
            )
        }
        state.notice?.let { notice ->
            item("notice") {
                Text(
                    notice,
                    color = Chotki.gold,
                    fontSize = 13.sp,
                    modifier = Modifier.fillMaxWidth().padding(top = 16.dp)
                        .clickable { state.notice = null },
                )
            }
        }
    }

    reading?.let { weekday ->
        PastEntries(state, weekday) { reading = null }
    }
}

// MARK: the header

@Composable
private fun SectionHead(
    state: AppState,
    explaining: Boolean,
    onToggleExplainer: () -> Unit,
    onTakeOn: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Reflections", color = Chotki.parchment, fontSize = 20.sp,
                fontFamily = Chotki.reading)
            Spacer(Modifier.size(10.dp))
            Text(
                "?",
                color = if (explaining) Chotki.gold else Chotki.muted,
                fontSize = 15.sp,
                modifier = Modifier.size(44.dp).wrapContent()
                    .clickable(onClick = onToggleExplainer)
                    .semantics { contentDescription = "What this is for" },
            )
            Spacer(Modifier.weight(1f))
            if (state.hasReflectionsOnRule) {
                // Stated as a fact, not as praise and not as a prompt to do
                // more. There is nothing left to press.
                Text("On your rule", color = Chotki.faint, fontSize = 12.sp)
            } else {
                // The explainer's last line tells the reader to click a button
                // of this name. For a while that button existed only on macOS,
                // so on a phone the text named something that was not there.
                // Both halves come from `addAsRuleLabel`, and PortParityTests
                // now fails if a platform lacks it.
                //
                // It opens the editor pre-filled rather than adding straight
                // away, because that is how everything is taken on here.
                Text(
                    Reflection.addAsRuleLabel,
                    color = Chotki.gold,
                    fontSize = 13.sp,
                    modifier = Modifier.clickable(onClick = onTakeOn),
                )
            }
        }
        if (explaining) Explainer()
    }
}

@Composable
private fun Explainer() {
    Column(
        Modifier.fillMaxWidth()
            .background(Chotki.panel, RoundedCornerShape(10.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        for (paragraph in Reflection.explainer) {
            Text(
                buildAnnotatedString {
                    for (span in paragraph.spans) {
                        if (span.url != null) {
                            withStyle(SpanStyle(
                                color = Chotki.gold,
                                textDecoration = TextDecoration.Underline,
                            )) { append(span.text) }
                        } else {
                            append(span.text)
                        }
                    }
                },
                color = Chotki.parchmentDim,
                fontSize = 14.sp,
                fontFamily = Chotki.reading,
                lineHeight = 21.sp,
            )
        }
    }
}

// MARK: one weekday

@Composable
private fun DayBlock(state: AppState, weekday: Weekday, onOpenPast: () -> Unit) {
    val reflection = state.reflection(weekday)
    val past = state.reflectionSeries(weekday).count
    val isToday = state.today.weekday == weekday
    var editing by remember { mutableStateOf(false) }
    var draft by remember(weekday) { mutableStateOf("") }
    var confirming by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().padding(bottom = 26.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                Format.weekdayName(weekday).uppercase(),
                color = Chotki.gold, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
            )
            if (isToday) {
                Spacer(Modifier.size(8.dp))
                Text(
                    "today",
                    color = Chotki.ground, fontSize = 10.sp, fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .background(Chotki.gold, RoundedCornerShape(3.dp))
                        .padding(horizontal = 5.dp, vertical = 1.dp),
                )
            }
            Spacer(Modifier.weight(1f))
            Text(
                if (past == 0) "no past entries"
                else if (past == 1) "1 past entry" else "$past past entries",
                color = if (past == 0) Chotki.faint else Chotki.muted,
                fontSize = 12.sp,
                modifier = if (past == 0) Modifier else Modifier.clickable(onClick = onOpenPast),
            )
        }
        HorizontalDivider(color = Chotki.line, modifier = Modifier.padding(top = 6.dp))

        if (editing) {
            QuestionEditor(reflection.question) { question ->
                if (question != null) state.rewriteReflection(weekday, question)
                editing = false
            }
            return@Column
        }

        Row(
            Modifier.fillMaxWidth().padding(top = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                reflection.title, color = Chotki.parchment, fontSize = 19.sp,
                fontFamily = Chotki.reading, modifier = Modifier.weight(1f),
            )
            Text(
                "Edit", color = Chotki.muted, fontSize = 12.sp,
                modifier = Modifier.clickable { editing = true },
            )
        }

        // Neither half is labelled. The task lines say "At the end of the day…"
        // themselves, and a word in the margin of the notice only named what
        // the whole section is already called.
        Text(
            reflection.notice, color = Chotki.parchmentDim, fontSize = 15.sp,
            fontFamily = Chotki.reading, lineHeight = 23.sp,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            reflection.task, color = Chotki.parchment, fontSize = 15.sp,
            fontFamily = Chotki.reading, lineHeight = 23.sp,
            modifier = Modifier.padding(top = 6.dp),
        )

        val written = state.answer(weekday)
        if (written != null) {
            Text(
                written.text, color = Chotki.parchment, fontSize = 15.sp,
                fontFamily = Chotki.reading, lineHeight = 23.sp,
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp)
                    .background(Chotki.panel, RoundedCornerShape(8.dp)).padding(12.dp),
            )
            Text(
                "Written ${Format.dateWithYear(written.date)}.",
                color = Chotki.faint, fontSize = 12.sp,
                modifier = Modifier.padding(top = 6.dp),
            )
        } else {
            Field(
                value = draft,
                onChange = { draft = it },
                placeholder = if (isToday) "Write today’s answer…"
                              else "Nothing written for this day yet.",
                minHeight = 96.dp,
                modifier = Modifier.padding(top = 12.dp),
            )
            Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                val ready = draft.isNotBlank()
                Text(
                    "Save",
                    color = if (ready) Chotki.gold else Chotki.faint,
                    fontSize = 15.sp,
                    modifier = if (ready) Modifier.clickable { confirming = true } else Modifier,
                )
                Spacer(Modifier.weight(1f))
                state.reflectionSeries(weekday).entries.firstOrNull()?.let {
                    Text(
                        "last written ${Format.dateWithYear(it.date)}",
                        color = Chotki.faint, fontSize = 12.sp,
                    )
                }
            }
        }
    }

    if (confirming) {
        AlertDialog(
            onDismissRequest = { confirming = false },
            title = { Text("Save this answer?") },
            text = { Text("Once saved it is kept as written and cannot be changed.") },
            confirmButton = {
                TextButton(onClick = {
                    state.saveReflection(weekday, draft)
                    draft = ""
                    confirming = false
                }) { Text("Save") }
            },
            dismissButton = {
                TextButton(onClick = { confirming = false }) { Text("Cancel") }
            },
            containerColor = Chotki.panel,
        )
    }
}

// MARK: rewriting a question

@Composable
private fun QuestionEditor(
    question: ReflectionQuestion,
    done: (ReflectionQuestion?) -> Unit,
) {
    var title by remember { mutableStateOf(question.title) }
    var notice by remember { mutableStateOf(question.notice) }
    var task by remember { mutableStateOf(question.task) }

    Column(Modifier.fillMaxWidth().padding(top = 12.dp)) {
        Label("Title")
        Field(title, { title = it }, "", 40.dp)
        Label("Notice")
        Field(notice, { notice = it }, "", 90.dp)
        Label("Then")
        Field(task, { task = it }, "", 70.dp)

        Text(
            "This changes the question from today onward. Every answer already written " +
                "keeps the question it was written against, and stays readable.",
            color = Chotki.muted, fontSize = 12.sp,
            modifier = Modifier.padding(top = 10.dp),
        )
        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            Text("Save", color = Chotki.gold, fontSize = 15.sp,
                modifier = Modifier.clickable {
                    done(ReflectionQuestion(title, notice, task))
                })
            Text("Cancel", color = Chotki.muted, fontSize = 15.sp,
                modifier = Modifier.clickable { done(null) })
        }
    }
}

@Composable
private fun Label(text: String) {
    Text(text, color = Chotki.faint, fontSize = 11.sp, modifier = Modifier.padding(top = 8.dp))
}

@Composable
private fun Field(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
    minHeight: androidx.compose.ui.unit.Dp,
    modifier: Modifier = Modifier,
) {
    // The min height belongs to the *field*, not the box around it. Put it on
    // the box and the field wraps its one line at the top, leaving five sixths
    // of a 96dp target inert — which is what happened, and it reads as a dead
    // control rather than a small one.
    androidx.compose.foundation.layout.Box(
        modifier.fillMaxWidth()
            .background(Chotki.panel, RoundedCornerShape(8.dp))
            .padding(10.dp),
    ) {
        if (value.isEmpty() && placeholder.isNotEmpty()) {
            Text(
                placeholder, color = Chotki.faint, fontSize = 15.sp,
                fontFamily = Chotki.reading, fontStyle = FontStyle.Italic,
            )
        }
        BasicTextField(
            value = value,
            onValueChange = onChange,
            textStyle = androidx.compose.ui.text.TextStyle(
                color = Chotki.parchment, fontSize = 15.sp,
                fontFamily = Chotki.reading, lineHeight = 23.sp,
            ),
            cursorBrush = SolidColor(Chotki.gold),
            modifier = Modifier.fillMaxWidth().heightIn(min = minHeight),
        )
    }
}

// MARK: reading back

/**
 * The dates a weekday holds, and one of them opened.
 *
 * A list rather than the Mac's arrows either side of a panel: at this width
 * there is nowhere for chevrons to go, and the shape of a year is visible at a
 * glance in a list in a way it never is behind a pair of arrows. iOS made the
 * same choice.
 */
@Composable
private fun PastEntries(state: AppState, weekday: Weekday, onClose: () -> Unit) {
    var open by remember { mutableStateOf<ReflectionEntry?>(null) }
    val entries = state.reflectionSeries(weekday).entries

    AlertDialog(
        onDismissRequest = onClose,
        containerColor = Chotki.panel,
        title = {
            Text(
                open?.let { Format.dateWithYear(it.date) } ?: Format.weekdayName(weekday),
                color = Chotki.parchment,
            )
        },
        text = {
            val entry = open
            if (entry == null) {
                LazyColumn {
                    items(entries, key = { it.id }) { held ->
                        Column(
                            Modifier.fillMaxWidth()
                                .clickable { open = held }
                                .padding(vertical = 8.dp),
                        ) {
                            Text(
                                Format.dateWithYear(held.date),
                                color = Chotki.parchment, fontSize = 15.sp,
                            )
                            Text(
                                held.text, color = Chotki.faint, fontSize = 13.sp,
                                fontFamily = Chotki.reading, maxLines = 2,
                            )
                        }
                    }
                }
            } else {
                // The question as it stood on that date, not as it stands now.
                LazyColumn {
                    item {
                        Text(entry.question.title, color = Chotki.parchment,
                            fontSize = 18.sp, fontFamily = Chotki.reading)
                        Text(entry.question.notice, color = Chotki.parchmentDim,
                            fontSize = 14.sp, fontFamily = Chotki.reading,
                            modifier = Modifier.padding(top = 8.dp))
                        Text(entry.question.task, color = Chotki.parchmentDim,
                            fontSize = 14.sp, fontFamily = Chotki.reading,
                            modifier = Modifier.padding(top = 6.dp))
                        HorizontalDivider(color = Chotki.line,
                            modifier = Modifier.padding(vertical = 12.dp))
                        Text(entry.text, color = Chotki.parchment, fontSize = 16.sp,
                            fontFamily = Chotki.reading, lineHeight = 24.sp)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { if (open != null) open = null else onClose() }) {
                Text(if (open != null) "Back" else "Done", color = Chotki.gold)
            }
        },
    )
}

// MARK: what closes the week

@Composable
private fun Colophon() {
    Column(Modifier.fillMaxWidth().padding(top = 18.dp)) {
        HorizontalDivider(color = Chotki.line)
        for (paragraph in Reflection.closingText) {
            Text(
                paragraph, color = Chotki.muted, fontSize = 14.sp,
                fontFamily = Chotki.reading, lineHeight = 22.sp,
                modifier = Modifier.padding(top = 12.dp),
            )
        }
    }
}

@Composable
private fun FileRow(onExport: () -> Unit, onImport: () -> Unit) {
    Column(Modifier.fillMaxWidth().padding(top = 20.dp)) {
        Text(
            "Kept on this phone, with everything else.",
            color = Chotki.faint, fontSize = 12.sp,
        )
        Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            Text("Export journal", color = Chotki.gold, fontSize = 15.sp,
                modifier = Modifier.clickable(onClick = onExport))
            Text("Import journal", color = Chotki.gold, fontSize = 15.sp,
                modifier = Modifier.clickable(onClick = onImport))
        }
    }
}

private fun Modifier.wrapContent(): Modifier = this
