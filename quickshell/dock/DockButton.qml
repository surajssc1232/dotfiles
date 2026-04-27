import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: btn

    property string appId:    ""
    property var    toplevel: null
    property bool   isPinned:  false
    property bool   isRunning: false
    property var    dockWinRef: null

    implicitWidth:  56
    implicitHeight: 56
    Layout.alignment: Qt.AlignVCenter

    // ── Icon ─────────────────────────────────────────────────────────────
    Image {
        id: icon
        anchors.centerIn: parent
        width:  btnHover.hovered ? 48 : 40
        height: btnHover.hovered ? 48 : 40
        source: Quickshell.iconPath(btn.appId, "application-x-executable")
        smooth: true
        mipmap: true

        Behavior on width  { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

        NumberAnimation on scale {
            id: bounceAnim
            from: 1.0; to: 0.82
            duration: 80; easing.type: Easing.OutQuad
            onFinished: backAnim.start()
        }
        NumberAnimation on scale {
            id: backAnim
            from: 0.82; to: 1.0
            duration: 140; easing.type: Easing.OutBounce
        }
    }

    // ── Running dot ───────────────────────────────────────────────────────
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        width: 5; height: 5; radius: 3
        color: btn.toplevel?.activated ? "#d79921" : "#458588"
        visible: btn.isRunning
    }

    // ── HoverHandler ──────────────────────────────────────────────────────
    HoverHandler {
        id: btnHover
        onHoveredChanged: {
            if (hovered) {
                let pt = btn.mapToItem(dockWinRef?.contentItem ?? btn,
                                       btn.width / 2, 0)
                tooltipState.x       = pt.x
                tooltipState.text    = btn.toplevel?.title ?? btn.appId
                tooltipState.visible = true
            } else {
                tooltipState.visible = false
            }
        }
    }

    // ── Keep tooltip live while hovered ───────────────────────────────────
    Connections {
        target: btn.toplevel
        enabled: btn.toplevel !== null && btnHover.hovered
        function onTitleChanged() {
            tooltipState.text = btn.toplevel.title
        }
    }

    // ── Left click: focus or launch ───────────────────────────────────────
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            bounceAnim.start()
            if (btn.toplevel) {
                btn.toplevel.activate()
            } else {
                launchProc.running = true
            }
        }
    }

    // ── Right click: close window ─────────────────────────────────────────
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: if (btn.toplevel) btn.toplevel.close()
    }

    // ── Launch process ────────────────────────────────────────────────────
    Process {
        id: launchProc
        command: ["sh", "-c", btn.appId]
        running: false
    }
}
