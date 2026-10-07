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
    readonly property var groups: [
        { heading: "The Day", items: ["Home"] },
        { heading: "To Read", items: ["Prayers", "Reading"] },
        { heading: "The Record", items: ["Progress", "Library"] },
        { heading: "Reference", items: ["Glossary", "Settings"] }
    ]
    readonly property var symbols: ({
        "Home": "▦", "Prayers": "❀", "Reading": "♧", "Progress": "⌁",
        "Library": "▦", "Glossary": "▤", "Settings": "⚙"
    })

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
                                    Label {
                                        text: window.symbols[modelData]
                                        width: 18
                                        color: window.section === modelData ? window.parchment : window.muted
                                        font.pixelSize: 15
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
                anchors.topMargin: 23
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

                Item { height: 42 }

                Label {
                    text: window.section === "Home" ? window.dayLabel() : window.section
                    color: window.parchment
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }

                Item { height: 18 }
                Rectangle { Layout.fillWidth: true; height: 1; color: window.lineSoft }
                Item { height: 24 }

                Label {
                    text: window.section === "Home" ? "Today's Commitments" : window.section
                    color: window.muted
                    font.pixelSize: 13
                }
                Item { height: 14 }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 196
                    color: window.panel
                    radius: 18
                    border.color: "#343237"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 60, 570)
                        spacing: 9
                        Label {
                            text: window.section === "Home" ? "The day begins here" : window.section
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            color: window.parchment
                            font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                            font.pixelSize: 24
                        }
                        Label {
                            text: window.section === "Home"
                                ? "The Linux window is connected to the same prayer record and calendar core."
                                : "This section is part of the desktop layout."
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            color: window.muted
                            font.pixelSize: 13
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Label {
                    text: bridge.connected
                        ? (bridge.review ? "Review record · " : "") + "Chotki core ready"
                        : bridge.status
                    color: bridge.connected ? window.muted : window.gold
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
}
