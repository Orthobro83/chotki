# Church practice

The app itself is not affiliated with any church. A person names their own, or says they have none yet.

## The rule

Written 2026-10-02. It applies to Android, Mac, and the redesigned iOS app now, and to a later Windows port.

When a church is selected, feasts, fasts, readings, prayers, akathists, and services follow that church. The cycles are the daily one, the weekly one, the monthly one, and the days appointed through the year. When no church is named, those same things follow the Orthodox Church in America: New Calendar, Russian tradition. Settings does not show "Orthodox Church in America" in that case. It shows "I don't have a church affiliation yet."

An existing record that already stored a church, and has no affiliation field, keeps that church. Choosing a church, or choosing none, is what changes it. Do not rewrite a live record to the new default.

## What already follows the church

The calendar is the church's reckoning. Fixed feasts, the fasting marks, and the appointed readings come from orthocal for that reckoning: `julian` or `gregorian`. Old and new calendars share Pascha, Great Lent, and Pentecost. They differ on the fixed feasts, by thirteen days.

The saint's life is the life of the observed church day. The Prologue from Ochrid records both the old-calendar date and the new-calendar date, and the reckoning picks which day is shown.

The Akathist Fridays are distances from Pascha. They are computed in the app, so a Friday a year ahead is not blank while that day is still being fetched. The rest of the reading — the feast, the fast, the scripture — still waits on the fetched day, and the screen says so.

The prayer for the departed is the daily Slavic commemoration. It is shown for the Russian, Serbian, and Bulgarian traditions. The OCA, ROCOR, Moscow, the Polish Orthodox Church, and the OCU are in the Russian tradition, so they are included. Romanian and Georgian are not.

Practice notes in Settings describe what that tradition customarily does, and they point to a priest. They are not instructions.

## What is still one text

The prayers are one public-domain English text. They are not a separate translation for each church. The app is not a full typikon: it does not carry a different order of every service for every church. What it does carry — the calendar's feasts and fasts, the readings, the Akathist, and the departed prayer — follows the church named above.

## The Akathist to the Theotokos

The hymn in the app is the 1919 English. The appointment is the church's, not a weekly rule and not a hymn chosen at random.

The service belongs to Friday evening. Saturday of the Akathist is the next morning. Old and new calendars share the Friday, because both compute Pascha the same way. In 2027 that Friday is 16 April, seventy-seven days after the Sunday of Zacchaeus and sixteen days before Pascha on 2 May.

### The whole hymn, on Friday of the fifth week only

This is the Slavic appointment: Matins of Saturday of the fifth week, served on Friday evening. The hymn is divided inside that one service. It is not spread across the first four Fridays.

- **Orthodox Church in America** (New Calendar). [Lenten services](https://www.oca.org/orthodoxy/the-orthodox-faith/worship/the-church-year/lenten-services): "On Friday evening of this same fifth week, the Akathistos Hymn to the Mother of God is sung." The outline is [Saturday of the 5th week](https://www.oca.org/liturgics/outlines/5th-sat-lent-akathist-hymn), Vespers served on Friday. The OCA does not publish a Salutations service for the first four Fridays.
- **Russian Orthodox Church Outside Russia**, the **Moscow Patriarchate**, and the **Polish Orthodox Church** (Old Calendar). The same Slavic typikon. [Saturday of the Akathist](https://orthochristian.com/120528.html) describes the whole hymn at Matins, usually on Friday evening, in four sections of that one service.
- **Serbian Orthodox Church** (Old Calendar) and the **Bulgarian Orthodox Church** (New Calendar). The same Slavic appointment: the Akathist on Friday evening of the fifth week, not on the first four Fridays.
- **Ukrainian Orthodox Church (OCU)** (New Calendar). Kept with the Slavic appointment, because that is this church's family in the app. Some parishes serve the Greek Salutations; the app does not switch a parish off the church's typikon on its own.

### One part on each of the first four Fridays, and the whole hymn on the fifth

This is the current Constantinopolitan order. Each of the first four Fridays is one stasis, six stanzas, framed by the kontakion. The fifth Friday is the whole hymn.

- **Greek Orthodox Archdiocese** and the **Ecumenical Patriarchate** (New Calendar). [Learn to Chant — the Akathist](https://www.goarch.org/-/learn-to-chant-the-akathist): "On the first four Fridays of Lent, according to the current Constantinopolitan practice, we chant the Service of the Salutations to the Theotokos at Small Compline. On the fifth Friday of Lent, we chant the Canon of the Akathist in its entirety." The order of the parts is also at [the Akathist Hymn](https://www.goarch.org/akathisthymn).
- **Church of Greece**, the **Church of Cyprus**, the **Albanian Orthodox Church** (New Calendar), and the **Patriarchate of Jerusalem** (Old Calendar). The same Constantinopolitan order. Greece, Cyprus, Albania, and Jerusalem are churches of that rite. A separate typikon page naming the Fridays was not found for Albania or Jerusalem. They are not given the OCA fallback: the order they are kept on is the one GOARCH publishes as current Constantinopolitan practice. If a later source shows one of them differs, change that church only.
- **Antiochian Orthodox Archdiocese** (New Calendar). The archdiocese's own texts: [Little Compline with the Akathist, Fridays 1–4](https://www.antiochian.org/dashboard?name=Great%20Lent), and the full hymn on Friday of the fifth week ([the fifth week of Great Lent](https://www.antiochian.org/regulararticle/2751)). The [spring 2025 liturgical instructions](https://www.antiochian.org/liturgicalinstructions/Liturgical%20Instructions%20Spring%202025.pdf) appoint the first stasis on the Friday of Clean Week and the following stases on the Fridays after it.

### No published appointment of its own

These two are shown the OCA's Friday — the whole hymn, on Friday of the fifth week — and the opened section says so. The four-Friday order is not asserted for either of them.

- **Romanian Orthodox Church** (New Calendar). A catechetical guide lists "Denia Acatistului Bunei Vestiri" on Friday of the fifth week only ([Agaton, Ghid de călătorie cu Hristos prin Postul Mare](https://www.agaton.ro/produs/4958/ghid-de-c%C4%83l%C4%83torie-cu-hristos-prin-postul-mare-%E2%80%93-lecturi-zilnice%E2%80%93)), and [ortodox.md](https://ortodox.md/saptamanile-postului-mare/) places the solemn akathist on Saturday of that week. That is the same day as the OCA. No patriarchate typikon page was found, so the app does not treat it as the church's own published appointment.
- **Georgian Orthodox Church** (Old Calendar). The patriarchate's calendar lists the fasts and the fixed feasts ([orthodoxy.ge](https://www.orthodoxy.ge/calendar/2026/2026.htm)). It does not list the Akathist Fridays. No four-Friday custom is asserted. Friday 16 April 2027 is the fifth-week Friday on both calendars, and the hymn is due that day.

Taking the Akathist on does not set fasting to Observed.
