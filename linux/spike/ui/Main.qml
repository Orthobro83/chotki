import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    width: 640
    height: 440
    visible: true
    title: "Chotki · Linux bridge proof"
    color: "#17252a"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 36
        spacing: 18

        Label {
            text: "Chotki on Linux"
            color: "#f2e9d8"
            font.pixelSize: 30
            font.bold: true
        }
        Label {
            text: bridge.status
            color: "#b8d2c8"
            font.pixelSize: 15
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: "#60736f" }
        Label {
            text: "Core date calculation: " + bridge.nextDay
            color: "#f2e9d8"
            font.pixelSize: 16
        }
        Label {
            text: "Core resource: " + bridge.resource
            color: "#f2e9d8"
            font.pixelSize: 16
        }
        Label {
            text: "Saved sample: " + bridge.saved
            color: "#f2e9d8"
            font.pixelSize: 16
        }
        RowLayout {
            TextField {
                id: sample
                Layout.fillWidth: true
                placeholderText: "Synthetic sample only"
                text: "Phase 0 saved on Linux"
            }
            Button { text: "Save"; onClicked: bridge.save(sample.text) }
        }
        RowLayout {
            Button { text: "Reload"; onClicked: bridge.refresh() }
            Button { text: "Test error path"; onClicked: bridge.probeError() }
        }
        Label {
            text: bridge.error.length > 0 ? "Bridge error: " + bridge.error : "No bridge errors"
            color: bridge.error.length > 0 ? "#e8ac9c" : "#b8d2c8"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
        Item { Layout.fillHeight: true }
        Label {
            text: "Phase 0 technical proof · disposable record under ~/.cache/chotki-phase0"
            color: "#8ca39c"
            font.pixelSize: 12
        }
    }
}
