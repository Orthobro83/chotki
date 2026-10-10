#pragma once

#include <QString>

// Reduced motion skips the opening mark. An explicit environment value is for
// tests and for a reader who has set it; otherwise GNOME's animation switch is used.
inline bool chotkiReducedMotion(const QString &environment, const QString &enableAnimations) {
    if (environment == "1" || environment == "true") return true;
    if (environment == "0" || environment == "false") return false;
    QString value = enableAnimations.trimmed();
    if (value.size() >= 2 && value.front() == '\'' && value.back() == '\'')
        value = value.mid(1, value.size() - 2);
    return value == "false";
}

// A new process may play the mark. Screenshot capture and reduced motion do not.
inline bool chotkiPlaysOpening(bool reducedMotion, bool capturingReview) {
    return !reducedMotion && !capturingReview;
}
