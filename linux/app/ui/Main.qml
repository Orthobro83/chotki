import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 1100
    height: 860
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: "Chotki"
    color: "#15161c"

    readonly property color ground: "#15161c"
    readonly property color panel: "#1c1e26"
    readonly property color parchment: "#e8dfcd"
    readonly property color muted: "#a39e8f"
    readonly property color gold: "#c9a227"
    readonly property color lineSoft: "#23252c"
    property string section: "Home"
    property bool openingPlayed: false
    property int openingStarts: 0
    property int heardEvent: -1

    function notePrayer() {
        if (bridge.prayerEvent > heardEvent && bridge.prayerSound.length > 0) {
            heardEvent = bridge.prayerEvent
            bridge.playSound(bridge.prayerSound)
        } else if (bridge.prayerEvent < heardEvent) {
            heardEvent = bridge.prayerEvent
        }
    }

    function maybeOpen() {
        if (!playOpening || openingPlayed || !bridge.openingReady) return
        openingPlayed = true
        openingStarts += 1
        openingLoader.active = true
    }
    readonly property var groups: [
        { heading: "The Day", items: ["Home"] },
        { heading: "To Read", items: ["Prayers", "Reading"] },
        { heading: "The Record", items: ["Progress", "Library"] },
        { heading: "Reference", items: ["Glossary", "Settings"] }
    ]

    Shortcut { sequence: "Ctrl+1"; onActivated: window.section = "Home" }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.section = "Prayers" }
    Shortcut { sequence: "Ctrl+3"; onActivated: window.section = "Reading" }
    Shortcut { sequence: "Ctrl+4"; onActivated: window.section = "Progress" }
    Shortcut { sequence: "Ctrl+5"; onActivated: window.section = "Library" }
    Shortcut { sequence: "Ctrl+6"; onActivated: window.section = "Glossary" }
    Shortcut { sequence: "Ctrl+7"; onActivated: window.section = "Settings" }

    FontLoader { id: charter; source: "fonts/XCharter-Roman.otf" }
    FontLoader { id: charterBold; source: "fonts/XCharter-Bold.otf" }

    function greeting() {
        const hour = new Date().getHours()
        const opening = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return opening + (bridge.displayName.length ? ", " + bridge.displayName : "")
    }

    function dayLabel() {
        if (!bridge.today.length) return ""
        const date = new Date(bridge.today + "T12:00:00")
        return Qt.formatDate(date, "dddd d MMMM")
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 188
            color: "#1d1e23"

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 3

                Label {
                    text: "▣"
                    width: parent.width
                    height: 60
                    leftPadding: 9
                    topPadding: 13
                    color: window.muted
                    font.pixelSize: 17
                    Accessible.name: "Sidebar"
                }

                Repeater {
                    model: window.groups
                    delegate: Column {
                        required property var modelData
                        width: 168
                        spacing: 3

                        Label {
                            text: modelData.heading
                            color: window.muted
                            opacity: 0.92
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            leftPadding: 10
                            topPadding: 12
                            bottomPadding: 4
                        }

                        Repeater {
                            model: modelData.items
                            delegate: Rectangle {
                                required property string modelData
                                objectName: "nav-" + modelData
                                width: 168
                                height: 36
                                color: window.section === modelData ? "#171920" : "transparent"
                                radius: 8
                                Accessible.name: modelData
                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Icon {
                                        kind: modelData
                                        width: 18
                                        height: 18
                                        tint: window.section === modelData ? window.parchment : window.muted
                                    }
                                    Label {
                                        text: modelData
                                        color: window.section === modelData ? window.parchment : window.muted
                                        font.pixelSize: 13
                                        font.weight: window.section === modelData ? Font.Medium : Font.Normal
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: window.section = modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Canvas {
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const context = getContext("2d")
                    context.reset()
                    context.fillStyle = window.ground
                    context.fillRect(0, 0, width, height)
                    const glow = context.createRadialGradient(width * 0.1, height * 0.15, 0,
                                                               width * 0.1, height * 0.15, width * 0.85)
                    glow.addColorStop(0, "#383538")
                    glow.addColorStop(1, "#15161c")
                    context.fillStyle = glow
                    context.fillRect(0, 0, width, height)
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 58
                anchors.bottomMargin: 18
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: window.section === "Home" ? window.greeting() : window.section
                        color: window.parchment
                        font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    Label {
                        visible: bridge.review
                        text: "REVIEW"
                        color: window.gold
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        rightPadding: 5
                    }
                }

                Loader {
                    id: homeLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: active
                    active: window.section === "Home"
                    visible: active
                    source: "Home.qml"
                }
                Connections {
                    target: homeLoader.item
                    function onLibraryRequested() { window.section = "Library" }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: active
                    active: window.section === "Prayers"
                    visible: active
                    source: "Prayers.qml"
                }
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: active
                    active: window.section === "Reading"
                    visible: active
                    source: "Reading.qml"
                }

                ColumnLayout {
                    visible: window.section !== "Home" && window.section !== "Prayers"
                            && window.section !== "Reading"
                    Layout.fillWidth: true
                    Layout.fillHeight: visible
                    Item { height: 46 }
                    Label {
                        text: window.section
                        color: window.parchment
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Item { height: 18 }
                    Rectangle { Layout.fillWidth: true; height: 1; color: window.lineSoft }
                    Item { height: 24 }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 196
                        color: window.panel
                        radius: 18
                        border.color: "#343237"
                        Column {
                            anchors.centerIn: parent
                            spacing: 9
                            Label {
                                text: window.section
                                color: window.parchment
                                font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                                font.pixelSize: 24
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Label {
                                text: "This section is part of the desktop layout."
                                color: window.muted
                                font.pixelSize: 13
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                Label {
                    visible: !bridge.connected
                    text: bridge.status
                    color: window.gold
                    font.pixelSize: 12
                }
                Label {
                    visible: bridge.error.length > 0
                    text: bridge.error
                    color: "#d9a396"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    Connections {
        target: bridge
        function onChanged() {
            window.notePrayer()
            window.maybeOpen()
        }
    }

    Loader {
        id: openingLoader
        anchors.fill: parent
        z: 40
        active: false
        source: "OpeningMark.qml"
        onLoaded: item.finished.connect(function() {
            Qt.callLater(function() { openingLoader.active = false })
        })
    }

    Component.onCompleted: maybeOpen()
}
