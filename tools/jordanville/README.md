# Turning the Jordanville scan into text

The prayer book Chotki is moving to is a 400-page scan with an OCR layer, not a
digital text. Holy Trinity Publications sell no ebook, and the only clean
transcription anyone has put online covers the Morning Prayers alone — on a
personal blog, with at least two slips of its own ("mightiest" for "mightest",
"angelic" for "angelical"). So the scan is the source, and the OCR has to be
repaired rather than trusted.

Nothing here changes a word of the book. Every rule repairs damage the scanner
did, and anything a rule cannot be sure of is left alone so it shows up in
review rather than passing silently.

## The three steps

| | |
|---|---|
| `extract.swift` | Pulls the text layer out with PDFKit, one marker per page. macOS ships it, so no poppler and no install on anyone's machine. |
| `clean.py` | Repairs the OCR. |
| `parse.py` | Finds the headings and gathers wrapped lines back into paragraphs. |

```bash
swift extract.swift jordanville-prayerbook.pdf > jv-raw.txt
python3 clean.py jv-raw.txt > jv-clean.txt
python3 parse.py jv-clean.txt out/section.json
```

## What the scanner does to this book, and what is done about it

- **`0` for the vocative `O`.** Everywhere. Replaced only where a digit cannot
  belong — standing alone, never inside a number.
- **Words broken across lines.** The book also contains real hyphens, and some
  fall at a line end: joining blindly turned "all-merciful" into
  "allmerciful". Each break is now decided against the system dictionary — if
  the halves make a word, join; if each half is a word already, the hyphen was
  the book's and is kept.
- **Drop caps.** A decorative initial spans two lines and the scanner emits
  garbage on both: `J\s I rise` and `J-\..` for what is simply "As I rise".
  Listed rather than guessed at, because inferring which letter a smudge was is
  how a prayer book acquires words nobody wrote.
- **Letters lost inside words.** `Hims.elf`, `he art`, `sl,eep`, `memo_ry`,
  `grac~`. Fixed where a stray mark sits between letters; listed individually
  where a letter has to be supplied.
- **Roman numerals.** `Prayer W` is Prayer IV; `PrayerV` lost its space.
- **Two words where a letter simply went.** "power and trength" is strength.
  "as Thou earnest among Thy disciples" is *camest* — Christ appearing among
  them, not earnestness. Both are unambiguous in context; both are listed
  explicitly so the judgement is visible rather than buried in a regex.

## What it cannot do

It repairs the scan. It does not decide what a prayer *is* — which headings are
prayers, which lines are the italic directions the scan flattens, what belongs
in a rule. That is editorial, and it is done by hand against `out/*.json`.

The service sections (Vespers, Matins, the Divine Liturgy) are markedly dirtier
than the personal prayers: speaker labels and small caps confuse the scanner,
leaving `&ader` for "Reader" and `£ver Virgin` for "Ever Virgin". The three
personal sections come out with no residual damage at all; those are done
first for that reason.
