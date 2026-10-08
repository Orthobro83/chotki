import QtQuick
import QtQuick.Controls

Item {
    id: home
    objectName: "home"
    signal libraryRequested()
    width: parent ? parent.width : 850
    height: parent ? parent.height : 700

    readonly property color parchment: "#e8dfcd"
    readonly property color muted: "#a39e8f"
    readonly property color gold: "#c9a227"
    readonly property color ink: "#1a1916"
    FontLoader { id: charter; source: "fonts/XCharter-Roman.otf" }

    function localDate(iso) {
        return iso.length ? new Date(iso + "T12:00:00") : new Date()
    }
    function monthLabel() {
        return bridge.selectedDate.length ? Qt.formatDate(localDate(bridge.selectedDate), "MMMM yyyy") : ""
    }
    function dateLabel() {
        return bridge.selectedDate.length ? Qt.formatDate(localDate(bridge.selectedDate), "dddd d MMMM") : ""
    }

    Flickable {
        anchors.fill: parent
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: 0

            Item { width: 1; height: 18 }
            Label {
                width: parent.width
                text: home.monthLabel()
                horizontalAlignment: Text.AlignHCenter
                color: home.parchment
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Item { width: 1; height: 8 }
            Row {
                x: (parent.width - width) / 2
                spacing: 6
                Label {
                    text: "‹"
                    width: 18
                    height: 53
                    verticalAlignment: Text.AlignVCenter
                    color: home.gold
                    font.pixelSize: 18
                    MouseArea { anchors.fill: parent; onClicked: bridge.shiftWeek(-1) }
                }
                Repeater {
                    model: bridge.week
                    delegate: Rectangle {
                        required property var modelData
                        objectName: "day-" + modelData.date
                        width: 42
                        height: 53
                        radius: 13
                        color: modelData.selected ? "#16181e" : modelData.fast ? "#3b344f" : "#1e2029"
                        border.width: modelData.selected ? 1 : 0
                        border.color: home.gold

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Label {
                                text: ["", "S", "M", "T", "W", "T", "F", "S"][modelData.weekday]
                                color: home.muted
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }
                            Label {
                                text: modelData.day
                                color: modelData.feast ? home.gold : home.parchment
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                width: 30
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: bridge.selectDate(modelData.date) }
                    }
                }
                Label {
                    text: "›"
                    width: 18
                    height: 53
                    verticalAlignment: Text.AlignVCenter
                    color: home.gold
                    font.pixelSize: 18
                    MouseArea { anchors.fill: parent; onClicked: bridge.shiftWeek(1) }
                }
            }
            Item { width: 1; height: 50 }
            Label {
                width: parent.width
                height: 18
                text: bridge.dayTitle
                color: home.muted
                font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                font.pixelSize: 15
            }
            Item { width: 1; height: 12 }
            Row {
                width: parent.width
                Label {
                    id: dateHeading
                    text: home.dateLabel()
                    color: home.parchment
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Item { width: Math.max(0, content.width - dateHeading.implicitWidth - oldStyleHeading.implicitWidth); height: 1 }
                Label {
                    id: oldStyleHeading
                    visible: bridge.showOldStyleDates && bridge.observedDate.length > 0
                             && bridge.observedDate !== bridge.selectedDate
                    text: visible ? Qt.formatDate(home.localDate(bridge.observedDate), "d MMM") + " o.s." : ""
                    color: home.muted
                    font.pixelSize: 12
                }
            }
            Item { width: 1; height: 17 }
            Row {
                spacing: 8
                Label { text: "Today's Commitments"; color: home.muted; font.pixelSize: 12 }
                Label {
                    text: "Add a New Rule"
                    color: home.gold
                    font.pixelSize: 12
                    MouseArea { anchors.fill: parent; onClicked: home.libraryRequested() }
                }
            }
            Item { width: 1; height: 17 }

            Flickable {
                width: parent.width
                height: 236
                contentWidth: cards.width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: cards
                    spacing: 12
                    Repeater {
                        model: bridge.entries
                        delegate: Rectangle {
                            required property var modelData
                            width: 132
                            height: 232
                            radius: 21
                            color: "#e7decb"

                            Label {
                                x: 14; y: 15
                                text: modelData.category
                                color: "#726e5f"
                                font.pixelSize: 11
                            }
                            Rectangle {
                                objectName: "completion-" + modelData.id
                                x: parent.width - 31; y: 10
                                width: 21; height: 21; radius: 11
                                color: modelData.kept || modelData.dispensed ? home.gold : "transparent"
                                border.color: "#b89842"
                                border.width: 1
                                Label {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: modelData.kept || modelData.dispensed
                                    color: home.ink
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !modelData.dispensed
                                    onClicked: bridge.toggleKept(modelData.id)
                                }
                            }
                            Label {
                                x: 14; y: 43
                                width: parent.width - 28
                                text: modelData.title
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                color: home.ink
                                font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                                font.pixelSize: 18
                            }
                            Label {
                                x: 14; y: 120
                                width: parent.width - 28
                                height: 72
                                text: modelData.summary
                                wrapMode: Text.Wrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                color: "#5f5b50"
                                font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                                font.pixelSize: 13
                            }
                            Label {
                                x: 14; y: 207
                                text: modelData.time
                                color: "#5f5b50"
                                font.pixelSize: 11
                            }
                        }
                    }
                    Rectangle {
                        width: 120
                        height: 232
                        radius: 21
                        color: "transparent"
                        border.color: "#7d671f"
                        border.width: 1
                        Label {
                            anchors.centerIn: parent
                            text: "+  Add"
                            color: home.gold
                            font.pixelSize: 14
                        }
                        MouseArea { anchors.fill: parent; onClicked: home.libraryRequested() }
                    }
                }
            }
            Item { width: 1; height: 17 }
            Rectangle {
                width: parent.width
                height: 270
                radius: 20
                color: "#27252a"
                clip: true
                Image {
                    anchors.fill: parent
                    source: bridge.artworkUrl
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1500
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#00000000" }
                        GradientStop { position: 0.58; color: "#42000000" }
                        GradientStop { position: 1; color: "#e0000000" }
                    }
                }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    spacing: 5
                    Label { text: "Sayings of the Church Fathers"; color: home.parchment; font.pixelSize: 11 }
                    Label {
                        width: parent.width
                        text: bridge.sayingText
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: home.parchment
                        font.family: charter.status === FontLoader.Ready ? charter.name : "serif"
                        font.pixelSize: 18
                    }
                    Label {
                        text: bridge.sayingAuthor + " · " + bridge.sayingSource
                        color: home.parchment
                        font.pixelSize: 12
                    }
                }
            }
            Item { width: 1; height: 24 }
        }
    }
}
