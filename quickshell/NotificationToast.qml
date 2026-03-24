import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

// A single notification toast popup
// stackIndex controls vertical position so multiple stack without overlapping
ShellRoot {

// ── Notification server ────────────────────────────────────────────────
NotificationServer {
    id: notifServer
    keepOnReload: true
    actionsSupported: true
    bodyMarkupSupported: true
    onNotification: notif => {
        // Prepend so newest is on top
        notifModel.insert(0, { notif: notif, notifId: notif.id })
        // Auto-dismiss after timeout (use notification's own expiry or 5s)
        var timeout = (notif.expireTimeout > 0 && notif.expireTimeout < 30000)
                      ? notif.expireTimeout : 5000
        Qt.createQmlObject(
            'import QtQuick; Timer { interval: ' + timeout + '; running: true; onTriggered: { destroy() } }',
            notifServer
        )
        // We use the notification's own tracked property to auto-remove
        notif.trackedChanged.connect(() => {
            if (!notif.tracked) removeNotif(notif.id)
        })
    }
}

ListModel { id: notifModel }

function removeNotif(id) {
    for (var i = 0; i < notifModel.count; i++) {
        if (notifModel.get(i).notifId === id) {
            notifModel.remove(i)
            return
        }
    }
}

// ── Notification popups ───────────────────────────────────────────────
Repeater {
    model: notifModel
    delegate: NotificationToast {
        required property var notif
        required property int notifId
        required property int index
        stackIndex: index
    }
}

PanelWindow {
    id: root
    required property var notif        // the Notification object
    required property int stackIndex   // 0 = topmost, 1 = below, etc.

    anchors.right: true
    anchors.top:   true

    // Stack notifications below the bar (58px) + stacking offset
    margins.top:   58 + (stackIndex * 90)
    margins.right: 14

    implicitWidth:  340
    implicitHeight: 76
    color: "transparent"

    // Slide in from right + fade
    property real toastOpacity: 0
    property real toastX: 40

    Component.onCompleted: {
        slideIn.start()
    }

    ParallelAnimation {
        id: slideIn
        NumberAnimation {
            target: toastWin; property: "toastOpacity"
            from: 0; to: 1
            duration: 250; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: toastWin; property: "toastX"
            from: 40; to: 0
            duration: 250; easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        // Offset the whole rectangle for the slide animation
        x: toastWin.toastX
        opacity: toastWin.toastOpacity
        radius: 12
        color: "#3c3836"           // gbBg1
        border.color: "#504945"    // gbBg2
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // App icon / urgency indicator
            Rectangle {
                width: 4
                height: parent.height - 8
                radius: 2
                color: notif.urgency === 2 ? "#fb4934"   // critical = red
                     : notif.urgency === 1 ? "#fabd2f"   // normal   = yellow
                     :                       "#b8bb26"   // low      = green
            }

            Column {
                Layout.fillWidth: true
                spacing: 4

                // App name + summary on one line
                RowLayout {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: notif.appName
                        color: "#a89984"    // gbFg4
                        font.pixelSize: 10
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillWidth: true }

                    // Dismiss button
                    Text {
                        text: "✕"
                        color: "#7c6f64"    // gbBg4
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: notif.dismiss()
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: notif.summary
                    color: "#ebdbb2"    // gbFg
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: notif.body !== ""
                    width: parent.width
                    text: notif.body
                    color: "#a89984"    // gbFg4
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
    }
}
