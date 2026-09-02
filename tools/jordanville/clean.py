"""Repairs the scan's OCR, mechanically and reversibly.

Every rule here fixes a pattern the scanner produces, not a wording choice:
the book's own words are never altered, only the damage to them. Anything a
rule cannot be sure about is left alone and shows up in review.
"""
import re, sys


# The scan breaks words across lines with a hyphen, but the book also contains
# real hyphens — "all-merciful", "Only-begotten", "life-creating" — and some of
# those fall at a line end too. Joining blindly produced "allmerciful".
#
# So each break is decided rather than assumed: if the two halves make a word,
# join them; if they do not but each half is a word on its own, it was a real
# hyphen and it is kept. macOS ships the dictionary this consults.
_WORDS = None

def _dictionary():
    global _WORDS
    if _WORDS is None:
        try:
            _WORDS = {w.strip().lower() for w in open("/usr/share/dict/words")}
        except OSError:
            _WORDS = set()
    return _WORDS

def _dehyphenate(t: str) -> str:
    words = _dictionary()

    def decide(m):
        left, right = m.group(1), m.group(2)
        joined = left + right
        if joined.lower() in words:
            return joined
        if left.lower() in words and right.lower() in words:
            return left + "-" + right      # a real compound that broke at a line end
        return joined                       # the scanner's own break

    return re.sub(r'([A-Za-z]+)-\n([A-Za-z]+)', decide, t)

def clean(raw: str) -> str:
    t = raw
    t = re.sub(r'<<<PAGE \d+>>>\n?', '', t)          # our own page marks
    t = re.sub(r'(?m)^\s*-?\s*\d{1,3}\s*-?\s*$\n?', '', t)   # printed page numbers
    t = re.sub(r'(?m)^L?\s*-\d+-\s*$\n?', '', t)

    # A drop cap spans two lines; the scanner emits garbage on both. The real
    # letter is recoverable from the word it begins, so these are listed rather
    # than guessed at.
    t = re.sub(r'J\\s\s+I rise', 'As I rise', t)
    t = re.sub(r'(?m)^J-\\\.\.\s*', '', t)
    t = re.sub(r'(?m)^[A-Z]?[\\/|~`\^]+[a-z]?\.?\s*$\n?', '', t)   # lone drop-cap debris

    t = _dehyphenate(t)
    t = re.sub(r'\bl\b(?=\s*[A-Z])', 'I', t)         # l misread for I

    # Zero for the vocative O. Only where a letter could not be: standing alone,
    # or leading a word. Never inside a number.
    t = re.sub(r'(?<![0-9])\b0\b(?![0-9])', 'O', t)

    # Stray marks the scanner adds between letters of one word.
    t = t.replace('Hims.elf', 'Himself').replace('he art', 'heart')
    t = t.replace('sl,eep', 'sleep').replace('Christ_', 'Christ')
    t = re.sub(r'(?<=[a-z]),(?=[a-z])', '', t)       # comma dropped inside a word
    t = re.sub(r'(?<=[a-z])\.(?=[a-z])', '', t)      # full stop dropped inside a word

    # Marks the scanner sprinkles inside words. Listed where a letter has to
    # be inferred, because guessing which letter a tilde was is how a prayer
    # book acquires words nobody wrote.
    t = t.replace('\u00b7', '')                       # middle dot
    t = re.sub(r'(?<=[a-z])_(?=[a-z])', '', t)       # memo_ry
    for wrong, right in [
        ('grac~', 'grace'), ('g~tes', 'gates'), ('~', ''),
        ('N aine', 'Name'), ('aine we bear', 'ame we bear'),
        # Roman numerals the scanner ran together or misread.
        ('Prayer W,', 'Prayer IV,'), ('PrayerV:', 'Prayer V:'),
        ('St.John', 'St. John'),
        # Words where a letter was lost. Each is unambiguous in context:
        # "power and trength", and "as Thou earnest among Thy disciples",
        # which is camest — Christ appearing among them, not earnestness.
        ('and trength', 'and strength'),
        ('Thou earnest among', 'Thou camest among'),
        ('[ of anyone', '[of anyone'),
    ]:
        t = t.replace(wrong, right)

    t = re.sub(r'[ \t]+', ' ', t)
    t = re.sub(r' *\n *', '\n', t)
    return t

if __name__ == "__main__":
    sys.stdout.write(clean(open(sys.argv[1], encoding="utf-8", errors="ignore").read()))
