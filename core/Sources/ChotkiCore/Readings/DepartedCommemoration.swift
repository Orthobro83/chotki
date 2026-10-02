import Foundation

/// The prayer said for the departed by name.
///
/// Remembering the dead is an ordinary part of the daily cycle in Slavic
/// practice — at home, at the Liturgy, and on the Saturdays of Souls — and
/// not a text that waits until someone has just died. The Panikhida is the
/// fuller service for a particular occasion. What is here is the prayer of
/// that commemoration, so the names have somewhere to be said.
///
/// Hapgood's General Panikhida, 1906. NN. is her own place for the names.
/// The words are not shortened and not reworded. "Exclamation" is a rubric
/// for who says the second paragraph; the paragraph itself is the prayer's
/// ending, and it is kept.
public enum DepartedCommemoration {
    public static let rubric = "The names are said where NN. stands."
    public static let paragraphs = [
        "O God of spirits, and of all flesh, who hast trampled down Death, and overthrown the Devil, and given life unto thy world: Do thou, the same Lord, give rest to the souls of thy departed servants, NN., in a place of brightness, a place of verdure, a place of repose, whence all sickness, sorrow and sighing have fled away. Pardon every transgression which they have committed, whether by word, or deed, or thought. For thou art a good God and lovest mankind; because there is no man who liveth and sinneth not: for thou only art without sin, and thy righteousness is to all eternity, and thy word is true.",
        "For thou art the Resurrection, and the Life, and the Repose of thy departed servants, NN., O Christ our God, and unto thee do we ascribe glory, together with thy Father who is from everlasting, and thine all-holy, and good, and life-giving Spirit, now, and ever, and unto ages of ages.",
        "Amen."
    ]
    public static let source = "Hapgood, Service Book, 1906"
    public static let sourceURL = "https://archive.org/details/ServiceBookOfHolyOrthodoxChurchByHapgood"
}
